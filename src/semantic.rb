# frozen_string_literal: true

SemanticError = Struct.new(:message, :line, :column, :length, :token, :kind) do
  def to_s
    "[Linha #{line}, Col #{column}] Erro Semântico: #{message}"
  end
end

# Análise semântica do Safira.
#
# Recebe a AST do Parser e a tabela de símbolos do Lexer e valida, na ordem
# em que o código aparece:
#   * Opção 1 — compatibilidade de tipos (com promoção numérica int -> float -> double)
#   * Opção 2 — variável utilizada sem declaração prévia
#   * Extra   — redeclaração de variável
#
# Não imprime nada: devolve erros em #errors e preenche o tipo de cada
# variável declarada na tabela de símbolos (#symbol_table).
class SemanticAnalyzer
  NUMERIC_RANK = { int: 0, float: 1, double: 2 }.freeze

  # Tipos de origem aceitos para cada tipo de destino.
  ASSIGNABLE_FROM = {
    int: %i[int],
    float: %i[int float],
    double: %i[int float double],
    char: %i[char]
  }.freeze

  TYPE_NAMES = {
    int: 'int', float: 'float', double: 'double', char: 'char', string: 'String'
  }.freeze

  def initialize(ast, symbol_table = [])
    @ast = ast
    @symbol_table = symbol_table
    @errors = []
    @declared = {}
    @analyzed = false
  end

  def analyze
    return @errors if @analyzed

    Array(@ast&.declarations).each do |node|
      analyze_node(node)
    rescue StandardError => e
      @errors << SemanticError.new("Falha interna na análise semântica: #{e.message}", 1, 1, 1, nil, :internal)
    end

    @analyzed = true
    @errors
  end

  def errors
    analyze
  end

  def valid?
    analyze.empty?
  end

  def symbol_table
    analyze
    @symbol_table
  end

  private

  def analyze_node(node)
    case node
    in VarDeclNode[type_token:, name_token:, expression:]
      analyze_declaration(type_token, name_token, expression)
    in AssignNode[target:, expression:]
      analyze_assignment(target, expression)
    else
      nil # nós ainda não tratados (if, while, funções...)
    end
  end

  def analyze_declaration(type_token, name_token, expression)
    # A expressão é avaliada antes de declarar o nome: 'int x = x;' usa x sem declaração.
    expr_type = infer_type(expression)

    if (previous = @declared[name_token.lexeme])
      report(name_token, "Variável '#{name_token.lexeme}' já declarada anteriormente na linha #{previous.line}.",
             :redeclaration)
      return
    end

    declare(name_token, type_token.lexeme)
    check_compatibility(name_token, type_token.lexeme.to_sym, expression, expr_type)
  end

  def analyze_assignment(target, expression)
    entry = @declared[target.lexeme]
    if entry.nil?
      report(target, "Variável '#{target.lexeme}' utilizada sem declaração prévia.", :undeclared_variable)
    end

    expr_type = infer_type(expression)
    check_compatibility(target, entry.type.to_sym, expression, expr_type) if entry
  end

  def declare(name_token, type)
    entry = @symbol_table.find { |s| s.name == name_token.lexeme }

    if entry
      entry.type = type
      entry.line = name_token.line # o lexer registra a 1ª aparição; aqui vale a declaração
    else
      entry = SymbolEntry.new(name_token.lexeme, type, name_token.line, @symbol_table.size + 1)
      @symbol_table << entry
    end

    @declared[name_token.lexeme] = entry
  end

  # Devolve :int, :float, :double, :char, :string, :error (já reportado) ou nil (sem expressão).
  def infer_type(expr)
    case expr
    in nil
      nil
    in NumberNode[token:]
      token.lexeme.match?(/[.eE]/) ? :float : :int
    in StringNode
      :string
    in CharNode
      :char
    in IdentifierNode[token:]
      identifier_type(token)
    in BinaryOpNode[left:, operator_token:, right:]
      binary_type(left, operator_token, right)
    else
      :error
    end
  end

  def identifier_type(token)
    entry = @declared[token.lexeme]
    if entry.nil?
      report(token, "Variável '#{token.lexeme}' utilizada sem declaração prévia.", :undeclared_variable)
      return :error
    end

    type = entry.type.to_sym
    type == :void ? :error : type
  end

  def binary_type(left, operator_token, right)
    left_type = infer_type(left)
    right_type = infer_type(right)
    return :error if left_type == :error || right_type == :error

    operator = operator_token.lexeme

    unless NUMERIC_RANK.key?(left_type) && NUMERIC_RANK.key?(right_type)
      report(operator_token,
             "Operador '#{operator}' não pode ser aplicado a #{TYPE_NAMES[left_type]} e #{TYPE_NAMES[right_type]}.",
             :invalid_operation)
      return :error
    end

    if operator == '%' && !(left_type == :int && right_type == :int)
      report(operator_token,
             "Operador '%' exige operandos inteiros (recebeu #{TYPE_NAMES[left_type]} e #{TYPE_NAMES[right_type]}).",
             :invalid_operation)
      return :error
    end

    [left_type, right_type].max_by { |type| NUMERIC_RANK[type] }
  end

  def check_compatibility(target_token, target_type, expression, expr_type)
    return if expr_type.nil? || expr_type == :error

    allowed = ASSIGNABLE_FROM[target_type]
    return if allowed.nil? || allowed.include?(expr_type)

    message = "Não é possível atribuir #{TYPE_NAMES[expr_type]} a '#{target_token.lexeme}' " \
              "(#{TYPE_NAMES[target_type]})."
    message += ' Possível perda de precisão.' if NUMERIC_RANK.key?(expr_type) && NUMERIC_RANK.key?(target_type)

    first, length = expression_span(expression, target_token)
    report(first, message, :type_mismatch, length)
  end

  # Primeiro token da expressão e quantas colunas ela ocupa (para o ^^^^ do diagnóstico).
  def expression_span(expression, fallback_token)
    tokens = collect_tokens(expression)
    return [fallback_token, fallback_token.lexeme.length] if tokens.empty?

    first = tokens.min_by { |t| [t.line, t.column] }
    last = tokens.max_by { |t| [t.line, t.column] }
    length = first.line == last.line ? last.column + last.lexeme.length - first.column : first.lexeme.length
    [first, length]
  end

  def collect_tokens(expr)
    case expr
    in BinaryOpNode[left:, operator_token:, right:]
      collect_tokens(left) + [operator_token] + collect_tokens(right)
    in { token: }
      [token]
    else
      []
    end
  end

  def report(token, message, kind, length = nil)
    @errors << SemanticError.new(message, token.line, token.column, length || token.lexeme.to_s.length, token, kind)
  end
end
