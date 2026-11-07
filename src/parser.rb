# frozen_string_literal: true

ProgramNode     = Data.define(:declarations)
FunctionDefNode = Data.define(:return_type, :name_token, :params, :body)
BlockNode       = Data.define(:statements)
VarDeclNode     = Data.define(:type_token, :name_token, :expression)
AssignNode      = Data.define(:target, :expression)
IncDecNode      = Data.define(:target, :operator_token)

BinaryOpNode    = Data.define(:left, :operator_token, :right)
UnaryOpNode     = Data.define(:operator_token, :operand)
IdentifierNode  = Data.define(:token)
NumberNode      = Data.define(:token)
StringNode      = Data.define(:token)
CharNode        = Data.define(:token)

IfNode          = Data.define(:keyword, :condition, :then_branch, :else_branch)
WhileNode       = Data.define(:keyword, :condition, :body)
ForNode         = Data.define(:keyword, :init, :condition, :update, :body)
ReturnNode      = Data.define(:keyword, :expression)

ParseError = Struct.new(:message, :line, :column, :token) do
  def lexeme = token&.lexeme
  def to_s = "[Linha #{line}, Col #{column}] Erro Sintático: #{message}"
end

class Parser
  class SyntaxAbort < StandardError; end
  private_constant :SyntaxAbort

  SYNC_TOKENS = %i[TIPO_DADO KW_IF KW_ELSE KW_WHILE KW_FOR KW_RETURN CHAVE_ESQ CHAVE_DIR].freeze
  PAREN_DELTA = { PARENTESE_ESQ: 1, PARENTESE_DIR: -1 }.freeze
  COMPOUND_ASSIGNMENTS = {
    OP_SOMA_ATRIB: :OP_SOMA,
    OP_SUB_ATRIB: :OP_SUB,
    OP_MULT_ATRIB: :OP_MULT,
    OP_DIV_ATRIB: :OP_DIV,
    OP_MOD_ATRIB: :OP_MOD
  }.freeze

  def initialize(tokens)
    @tokens = tokens + [build_eof(tokens)]
    @pos = 0
    @errors = []
    @ast = nil
    @parsed = false
    @block_depth = 0
  end

  def peek = @tokens[@pos]
  def peek_next = @tokens[@pos + 1]
  def previous = @tokens[@pos - 1]
  def at_end? = peek.type == :EOF
  def check?(type) = peek.type == type

  def advance
    token = peek
    @pos += 1 unless at_end?
    token
  end

  def match?(*types)
    return false unless types.any? { |type| check?(type) }

    advance
    true
  end

  def consume(type, message)
    return advance if check?(type)

    raise_syntax_error(peek, message)
  end

  def parse
    return @ast if @parsed

    declarations = []
    append_statement(declarations, parse_statement_with_recovery) until at_end?

    @parsed = true
    @ast = ProgramNode.new(declarations: declarations)
  end

  def errors
    parse
    @errors
  end

  def valid? = errors.empty?

  private

  def parse_statement_with_recovery
    start_pos = @pos
    parse_statement
  rescue SyntaxAbort
    synchronize(start_pos)
    nil
  end

  def append_statement(statements, statement)
    if statement.is_a?(Array)
      statements.concat(statement)
    elsif statement
      statements << statement
    end
  end

  def parse_statement
    case peek.type
    when :TIPO_DADO then parse_declaration
    when :IDENTIFICADOR, :OP_INC, :OP_DEC then parse_assignment_statement
    when :KW_IF then parse_if
    when :KW_WHILE then parse_while
    when :KW_FOR then parse_for
    when :KW_RETURN then parse_return
    when :CHAVE_ESQ then parse_block
    when :KW_ELSE then report_dangling_else
    when :CHAVE_DIR then report_unexpected_brace
    else
      raise_syntax_error(peek, "Comando inválido ou inesperado #{describe(peek)}")
    end
  end

  def parse_declaration
    type_token = advance
    return parse_function(type_token) if check?(:IDENTIFICADOR) && peek_next.type == :PARENTESE_ESQ

    declarations = parse_declarators(type_token)
    consume_or_insert(:PONTO_VIRGULA, "Esperado ';' após a declaração de '#{declarations.last.name_token.lexeme}'")
    declarations.size == 1 ? declarations.first : declarations
  end

  def parse_declarators(type_token = advance)
    declarations = []

    loop do
      name_token = consume(:IDENTIFICADOR, "Esperado identificador após o tipo '#{type_token.lexeme}'")
      expression = match?(:OP_ATRIB) ? parse_expression : nil
      declarations << VarDeclNode.new(type_token: type_token, name_token: name_token, expression: expression)
      break unless match?(:VIRGULA)
    end

    declarations
  end

  def parse_function(return_type)
    name_token = advance
    if @block_depth.positive?
      raise_syntax_error(name_token, "A função '#{name_token.lexeme}' só pode ser definida fora de blocos")
    end

    advance
    params = parse_parameters
    consume(:PARENTESE_DIR, "Esperado ')' após os parâmetros de '#{name_token.lexeme}'")
    raise_syntax_error(peek, "Esperado '{' para abrir o corpo da função '#{name_token.lexeme}'") unless check?(:CHAVE_ESQ)

    FunctionDefNode.new(return_type: return_type, name_token: name_token, params: params, body: parse_block)
  end

  def parse_parameters
    return [] if check?(:PARENTESE_DIR)

    if peek.lexeme == 'void' && peek_next.type == :PARENTESE_DIR
      advance
      return []
    end

    params = []
    loop do
      type_token = consume(:TIPO_DADO, "Esperado o tipo do parâmetro, mas foi encontrado #{describe(peek)}")
      name_token = consume(:IDENTIFICADOR, "Esperado o nome do parâmetro após '#{type_token.lexeme}'")
      params << VarDeclNode.new(type_token: type_token, name_token: name_token, expression: nil)
      break unless match?(:VIRGULA)
    end
    params
  end

  def parse_assignment_statement
    statement = parse_simple_assignment('no início do comando')
    consume_or_insert(:PONTO_VIRGULA, "Esperado ';' após #{describe_simple_statement(statement)}")
    statement
  end

  def parse_simple_assignment(context)
    if match?(:OP_INC, :OP_DEC)
      operator_token = previous
      target = consume(:IDENTIFICADOR, "Esperado identificador após '#{operator_token.lexeme}'")
      return IncDecNode.new(target: target, operator_token: operator_token)
    end

    target = consume(:IDENTIFICADOR, "Esperado uma atribuição #{context}, mas foi encontrado #{describe(peek)}")
    return IncDecNode.new(target: target, operator_token: previous) if match?(:OP_INC, :OP_DEC)

    if match?(*COMPOUND_ASSIGNMENTS.keys)
      compound_operator = previous
      operator_type = COMPOUND_ASSIGNMENTS[compound_operator.type]
      operator_token = Token.new(operator_type, compound_operator.lexeme[0],
                                 compound_operator.line, compound_operator.column)
      # Desaçucara 'i op= expr' em 'i = i op (expr)'.
      expression = BinaryOpNode.new(left: IdentifierNode.new(token: target),
                                    operator_token: operator_token, right: parse_expression)
      return AssignNode.new(target: target, expression: expression)
    end

    consume(:OP_ATRIB, "Esperado '=' na atribuição para '#{target.lexeme}'")
    AssignNode.new(target: target, expression: parse_expression)
  end

  def describe_simple_statement(statement)
    case statement
    in IncDecNode[target:, operator_token:]
      prefix = ([operator_token.line, operator_token.column] <=> [target.line, target.column]).negative?
      prefix ? "'#{operator_token.lexeme}#{target.lexeme}'" : "'#{target.lexeme}#{operator_token.lexeme}'"
    in AssignNode[target:]
      "a atribuição para '#{target.lexeme}'"
    end
  end

  def parse_block
    @block_depth += 1
    open_brace = advance
    statements = []
    append_statement(statements, parse_statement_with_recovery) until check?(:CHAVE_DIR) || at_end?

    if at_end?
      record_error(open_brace, "Bloco aberto aqui não foi fechado: esperado '}' antes do fim do arquivo")
    else
      advance
    end

    BlockNode.new(statements: statements)
  ensure
    @block_depth -= 1
  end

  def parse_if
    keyword = advance
    condition = parse_condition(keyword)
    then_branch = parse_body
    else_branch = match?(:KW_ELSE) ? parse_body : nil
    IfNode.new(keyword: keyword, condition: condition, then_branch: then_branch, else_branch: else_branch)
  end

  def parse_while
    keyword = advance
    condition = parse_condition(keyword)
    WhileNode.new(keyword: keyword, condition: condition, body: parse_body)
  end

  def parse_for
    keyword = advance
    consume(:PARENTESE_ESQ, "Esperado '(' após 'for'")
    init = parse_for_init
    consume_or_insert(:PONTO_VIRGULA, "Esperado ';' após a inicialização do 'for'")
    condition = check?(:PONTO_VIRGULA) ? nil : parse_expression
    consume_or_insert(:PONTO_VIRGULA, "Esperado ';' após a condição do 'for'")
    update = check?(:PARENTESE_DIR) ? nil : parse_simple_assignment("no passo do 'for'")
    consume_or_insert(:PARENTESE_DIR, "Esperado ')' para fechar o cabeçalho do 'for'")

    ForNode.new(keyword: keyword, init: init, condition: condition, update: update, body: parse_body)
  end

  def parse_for_init
    return [] if check?(:PONTO_VIRGULA)
    return parse_declarators if check?(:TIPO_DADO)

    [parse_simple_assignment("na inicialização do 'for'")]
  end

  def parse_return
    keyword = advance
    expression = check?(:PONTO_VIRGULA) || check?(:CHAVE_DIR) ? nil : parse_expression
    consume_or_insert(:PONTO_VIRGULA, "Esperado ';' após o 'return'")
    ReturnNode.new(keyword: keyword, expression: expression)
  end

  # Sem '(', registra o erro mas ainda lê a condição para aproveitar o resto do comando.
  def parse_condition(keyword)
    opened = match?(:PARENTESE_ESQ)
    record_error(peek, "A condição do '#{keyword.lexeme}' deve estar entre parênteses") unless opened

    condition = parse_expression
    if opened
      consume_or_insert(:PARENTESE_DIR, "Esperado ')' para fechar a condição do '#{keyword.lexeme}'")
    else
      match?(:PARENTESE_DIR)
    end
    condition
  end

  # Declaração múltipla sem chaves (ex.: corpo de 'if') vira um BlockNode.
  def parse_body
    statement = parse_statement_with_recovery
    statement.is_a?(Array) ? BlockNode.new(statements: statement) : statement
  end

  def report_dangling_else
    record_error(advance, "'else' sem um 'if' correspondente")
    nil
  end

  def report_unexpected_brace
    raise_syntax_error(peek, "Esperado um comando antes de '}'") if @block_depth.positive?

    record_error(advance, "'}' sem um '{' correspondente")
    nil
  end

  # Precedência, da mais fraca para a mais forte: || → && → == != → < > <= >= → + - → * / % → unário
  def parse_expression
    parse_logical_or
  end

  def parse_logical_or
    parse_left_associative(:OP_OU_LOGICO) { parse_logical_and }
  end

  def parse_logical_and
    parse_left_associative(:OP_E_LOGICO) { parse_equality }
  end

  def parse_equality
    parse_left_associative(:OP_IGUAL, :OP_DIFERENTE) { parse_relational }
  end

  def parse_relational
    parse_left_associative(:OP_MENOR, :OP_MAIOR, :OP_MENOR_IGUAL, :OP_MAIOR_IGUAL) { parse_additive }
  end

  def parse_additive
    parse_left_associative(:OP_SOMA, :OP_SUB) { parse_term }
  end

  def parse_term
    parse_left_associative(:OP_MULT, :OP_DIV, :OP_MOD) { parse_unary }
  end

  def parse_left_associative(*operators)
    node = yield
    while match?(*operators)
      operator_token = previous
      node = BinaryOpNode.new(left: node, operator_token: operator_token, right: yield)
    end
    node
  end

  def parse_unary
    return parse_factor unless match?(:OP_NAO, :OP_SUB)

    operator_token = previous
    UnaryOpNode.new(operator_token: operator_token, operand: parse_unary)
  end

  def parse_factor
    return NumberNode.new(token: previous) if match?(:NUMERO)
    return StringNode.new(token: previous) if match?(:LITERAL_STRING)
    return CharNode.new(token: previous) if match?(:LITERAL_CHAR)
    return IdentifierNode.new(token: previous) if match?(:IDENTIFICADOR)

    if match?(:PARENTESE_ESQ)
      open_paren = previous
      expression = parse_expression
      consume_or_insert(
        :PARENTESE_DIR,
        "Esperado ')' para fechar '(' aberto na linha #{open_paren.line}, coluna #{open_paren.column}"
      )
      return expression
    end

    raise_syntax_error(peek, "Expressão esperada, mas foi encontrado #{describe(peek)}")
  end

  # Se o token esperado falta mas o próximo já inicia outra construção, aponta o erro sem abortar.
  def consume_or_insert(type, message)
    return advance if check?(type)
    raise_syntax_error(peek, message) unless resumable_after_missing?

    last = previous
    @errors << ParseError.new(message, last.line, last.column + last.lexeme.to_s.length, nil)
    nil
  end

  def resumable_after_missing?
    at_end? ||
      peek.line > previous.line ||
      check?(:PONTO_VIRGULA) ||
      SYNC_TOKENS.include?(peek.type)
  end

  def describe(token) = token.type == :EOF ? 'fim do arquivo' : "'#{token.lexeme}'"

  def raise_syntax_error(token, message)
    record_error(token, message)
    raise SyntaxAbort
  end

  def record_error(token, message)
    @errors << ParseError.new(message, token.line, token.column, token)
  end

  # Descarta tokens até ';' (fora de parênteses) ou início de comando/bloco, sem consumir '}'.
  def synchronize(start_pos)
    advance if @pos == start_pos && !at_end? && !(check?(:CHAVE_DIR) && @block_depth.positive?)
    depth = @tokens[start_pos...@pos].sum { |token| PAREN_DELTA.fetch(token.type, 0) }

    until at_end?
      return if depth <= 0 && @pos > start_pos && previous.type == :PONTO_VIRGULA
      return if check?(:CHAVE_DIR) || (depth <= 0 && SYNC_TOKENS.include?(peek.type))

      depth += PAREN_DELTA.fetch(peek.type, 0)
      advance
    end
  end

  def build_eof(tokens)
    last = tokens.last
    return Token.new(:EOF, '', 1, 1) if last.nil?

    Token.new(:EOF, '', last.line, last.column + last.lexeme.to_s.length)
  end
end
