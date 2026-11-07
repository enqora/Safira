# frozen_string_literal: true

SemanticError = Struct.new(:message, :line, :column, :length, :token, :kind) do
  def to_s
    "[Linha #{line}, Col #{column}] Erro Semântico: #{message}"
  end
end

class SemanticAnalyzer
  NUMERIC_RANK = { int: 0, float: 1, double: 2 }.freeze

  ASSIGNABLE_FROM = {
    int: %i[int],
    float: %i[int float],
    double: %i[int float double],
    char: %i[char]
  }.freeze

  TYPE_NAMES = {
    int: 'int', float: 'float', double: 'double', char: 'char', string: 'String', void: 'void'
  }.freeze

  SCALAR_TYPES         = %i[int float double char].freeze
  COMPARISON_OPERATORS = %w[< > <= >= == !=].freeze
  LOGICAL_OPERATORS    = %w[&& ||].freeze

  def initialize(ast, symbol_table = [])
    @ast = ast
    @symbol_table = symbol_table
    @errors = []
    @scopes = [{}]
    @function_returns = {}.compare_by_identity
    @current_function = nil
    @analyzed = false
  end

  def analyze
    return @errors if @analyzed

    Array(@ast&.declarations).each do |node|
      analyze_node(node)
    rescue StandardError => error
      @errors << SemanticError.new("Falha interna na análise semântica: #{error.message}", 1, 1, 1, nil, :internal)
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
    in IncDecNode[target:, operator_token:]
      analyze_inc_dec(target, operator_token)
    in BlockNode[statements:]
      within_scope { statements.each { |statement| analyze_node(statement) } }
    in IfNode[keyword:, condition:, then_branch:, else_branch:]
      check_condition(keyword, condition)
      analyze_node(then_branch)
      analyze_node(else_branch)
    in WhileNode[keyword:, condition:, body:]
      check_condition(keyword, condition)
      analyze_node(body)
    in ForNode[keyword:, init:, condition:, update:, body:]
      within_scope do
        init.each { |statement| analyze_node(statement) }
        check_condition(keyword, condition)
        analyze_node(update)
        analyze_node(body)
      end
    in FunctionDefNode
      analyze_function(node)
    in ReturnNode[keyword:, expression:]
      analyze_return(keyword, expression)
    else
      nil
    end
  end

  def analyze_declaration(type_token, name_token, expression)
    if type_token.lexeme == 'void'
      report(name_token, "Variável '#{name_token.lexeme}' não pode ser do tipo 'void'.", :invalid_type)
      return
    end

    expression_type = infer_type(expression)
    return if declare(name_token, type_token.lexeme, 'Variável').nil?

    check_compatibility(name_token, type_token.lexeme.to_sym, expression, expression_type)
  end

  def analyze_assignment(target, expression)
    entry = lookup_variable(target)
    expression_type = infer_type(expression)
    check_compatibility(target, entry.type.to_sym, expression, expression_type) if entry
  end

  def analyze_inc_dec(target, operator_token)
    entry = lookup_variable(target)
    return if entry.nil?

    type = entry.type.to_sym
    return if NUMERIC_RANK.key?(type)

    report(operator_token,
           "Operador '#{operator_token.lexeme}' exige uma variável numérica ('#{target.lexeme}' é #{TYPE_NAMES[type]}).",
           :invalid_operation)
  end

  # Parâmetros e corpo da função compartilham o mesmo escopo, como em C.
  def analyze_function(node)
    node => FunctionDefNode[return_type:, name_token:, params:, body:]
    parameter_types = params.map { |param| param.type_token.lexeme }.join(', ')
    entry = declare(name_token, "função #{return_type.lexeme}(#{parameter_types})", 'Função')
    @function_returns[entry] = return_type.lexeme.to_sym if entry

    @current_function = node
    within_scope do
      params.each do |param|
        if param.type_token.lexeme == 'void'
          report(param.name_token, "Parâmetro '#{param.name_token.lexeme}' não pode ser do tipo 'void'.", :invalid_type)
        else
          analyze_node(param)
        end
      end
      body.statements.each { |statement| analyze_node(statement) }
    end
  ensure
    @current_function = nil
  end

  def analyze_return(keyword, expression)
    expression_type = infer_type(expression)
    return report(keyword, "'return' utilizado fora de uma função.", :invalid_return) if @current_function.nil?

    name = @current_function.name_token.lexeme
    return_type = @current_function.return_type.lexeme.to_sym

    if return_type == :void
      report_span(expression, keyword, "A função '#{name}' é void e não pode retornar um valor.", :invalid_return) if expression
      return
    end

    return if compatible?(return_type, expression_type)

    message = "Não é possível retornar #{TYPE_NAMES[expression_type]} na função '#{name}' " \
              "(#{TYPE_NAMES[return_type]}).#{precision_note(return_type, expression_type)}"
    report_span(expression, keyword, message, :type_mismatch)
  end

  def check_condition(keyword, condition)
    type = infer_type(condition)
    return if type.nil? || type == :error || SCALAR_TYPES.include?(type)

    report_span(condition, keyword,
                "A condição do '#{keyword.lexeme}' deve ser numérica, mas recebeu #{TYPE_NAMES[type]}.",
                :invalid_condition)
  end

  def within_scope
    @scopes.push({})
    yield
  ensure
    @scopes.pop
  end

  # Redeclaração só é erro dentro do mesmo escopo; em um bloco interno, o nome pode
  # ser declarado de novo (sombreamento) e ganha uma nova linha na tabela de símbolos.
  def declare(name_token, type, noun)
    name = name_token.lexeme
    if (previous = @scopes.last[name])
      report(name_token, "#{noun} '#{name}' já declarada anteriormente na linha #{previous.line}.", :redeclaration)
      return nil
    end

    @scopes.last[name] = register_symbol(name_token, type)
  end

  def register_symbol(name_token, type)
    entry = @symbol_table.find { |s| s.name == name_token.lexeme && s.type.nil? }

    if entry
      entry.type = type
      entry.line = name_token.line
    else
      entry = SymbolEntry.new(name_token.lexeme, type, name_token.line, @symbol_table.size + 1)
      @symbol_table << entry
    end

    entry
  end

  def lookup(name)
    @scopes.reverse_each do |scope|
      return scope[name] if scope.key?(name)
    end
    nil
  end

  def lookup_variable(token)
    entry = lookup(token.lexeme)

    if entry.nil?
      report(token, "Variável '#{token.lexeme}' utilizada sem declaração prévia.", :undeclared_variable)
      return nil
    end

    if @function_returns.key?(entry)
      report(token, "'#{token.lexeme}' é uma função e não pode ser usada como variável.", :invalid_operation)
      return nil
    end

    entry
  end

  def infer_type(expression)
    case expression
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
    in UnaryOpNode[operator_token:, operand:]
      unary_type(operator_token, operand)
    in BinaryOpNode[left:, operator_token:, right:]
      binary_type(left, operator_token, right)
    else
      :error
    end
  end

  def identifier_type(token)
    entry = lookup_variable(token)
    return :error if entry.nil?

    type = entry.type.to_sym
    type == :void ? :error : type
  end

  def unary_type(operator_token, operand)
    operand_type = infer_type(operand)
    return :error if operand_type == :error

    operator = operator_token.lexeme
    return :int if operator == '!' && SCALAR_TYPES.include?(operand_type)
    return operand_type if operator == '-' && NUMERIC_RANK.key?(operand_type)

    report(operator_token, "Operador '#{operator}' não pode ser aplicado a #{TYPE_NAMES[operand_type]}.",
           :invalid_operation)
    :error
  end

  def binary_type(left, operator_token, right)
    left_type = infer_type(left)
    right_type = infer_type(right)
    return :error if left_type == :error || right_type == :error

    case operator_token.lexeme
    when *LOGICAL_OPERATORS then logical_type(operator_token, left_type, right_type)
    when *COMPARISON_OPERATORS then comparison_type(operator_token, left_type, right_type)
    else arithmetic_type(operator_token, left_type, right_type)
    end
  end

  def arithmetic_type(operator_token, left_type, right_type)
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

  # Comparações e operadores lógicos resultam em int (0 ou 1), como em C.
  def comparison_type(operator_token, left_type, right_type)
    both_numeric = NUMERIC_RANK.key?(left_type) && NUMERIC_RANK.key?(right_type)
    return :int if both_numeric || (left_type == :char && right_type == :char)

    report(operator_token,
           "Operador '#{operator_token.lexeme}' não pode comparar #{TYPE_NAMES[left_type]} e #{TYPE_NAMES[right_type]}.",
           :invalid_operation)
    :error
  end

  def logical_type(operator_token, left_type, right_type)
    return :int if SCALAR_TYPES.include?(left_type) && SCALAR_TYPES.include?(right_type)

    report(operator_token,
           "Operador '#{operator_token.lexeme}' não pode ser aplicado a " \
           "#{TYPE_NAMES[left_type]} e #{TYPE_NAMES[right_type]}.",
           :invalid_operation)
    :error
  end

  def check_compatibility(target_token, target_type, expression, expression_type)
    return if compatible?(target_type, expression_type)

    message = "Não é possível atribuir #{TYPE_NAMES[expression_type]} a '#{target_token.lexeme}' " \
              "(#{TYPE_NAMES[target_type]}).#{precision_note(target_type, expression_type)}"
    report_span(expression, target_token, message, :type_mismatch)
  end

  def compatible?(target_type, expression_type)
    return true if expression_type.nil? || expression_type == :error

    allowed_types = ASSIGNABLE_FROM[target_type]
    allowed_types.nil? || allowed_types.include?(expression_type)
  end

  def precision_note(target_type, expression_type)
    NUMERIC_RANK.key?(expression_type) && NUMERIC_RANK.key?(target_type) ? ' Possível perda de precisão.' : ''
  end

  def report_span(expression, fallback_token, message, kind)
    first_token, length = expression_span(expression, fallback_token)
    report(first_token, message, kind, length)
  end

  def expression_span(expression, fallback_token)
    tokens = collect_tokens(expression)
    return [fallback_token, fallback_token.lexeme.length] if tokens.empty?

    first_token = tokens.min_by { |token| [token.line, token.column] }
    last_token = tokens.max_by { |token| [token.line, token.column] }
    length = if first_token.line == last_token.line
               last_token.column + last_token.lexeme.length - first_token.column
             else
               first_token.lexeme.length
             end
    [first_token, length]
  end

  def collect_tokens(expression)
    case expression
    in BinaryOpNode[left:, operator_token:, right:]
      collect_tokens(left) + [operator_token] + collect_tokens(right)
    in UnaryOpNode[operator_token:, operand:]
      [operator_token] + collect_tokens(operand)
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
