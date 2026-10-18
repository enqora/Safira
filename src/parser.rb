# frozen_string_literal: true

ProgramNode     = Data.define(:declarations)
FunctionDefNode = Data.define(:return_type, :name_token, :params, :body)
BlockNode       = Data.define(:statements)
VarDeclNode     = Data.define(:type_token, :name_token, :expression)
AssignNode      = Data.define(:target, :expression)

BinaryOpNode    = Data.define(:left, :operator_token, :right)
IdentifierNode  = Data.define(:token)
NumberNode      = Data.define(:token)
StringNode      = Data.define(:token)
CharNode        = Data.define(:token)

IfNode          = Data.define(:condition, :then_branch, :else_branch)
WhileNode       = Data.define(:condition, :body)
ReturnNode      = Data.define(:expression)

ParseError = Struct.new(:message, :line, :column, :token) do
  def lexeme
    token&.lexeme
  end

  def to_s
    "[Linha #{line}, Col #{column}] Erro Sintático: #{message}"
  end
end

class Parser
  class SyntaxAbort < StandardError; end
  private_constant :SyntaxAbort

  def initialize(tokens)
    @tokens = tokens + [build_eof(tokens)]
    @pos = 0
    @errors = []
    @ast = nil
    @parsed = false
  end

  def peek = @tokens[@pos]

  def previous = @pos.positive? ? @tokens[@pos - 1] : @tokens[0]

  def at_end? = peek.type == :EOF

  def advance
    token = peek
    @pos += 1 unless at_end?
    token
  end

  def check?(type) = peek.type == type

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
    until at_end?
      start_pos = @pos
      begin
        statement = parse_statement
        if statement.is_a?(Array)
          declarations.concat(statement)
        elsif statement
          declarations << statement
        end
      rescue SyntaxAbort
        synchronize(start_pos)
      rescue StandardError => error
        record_error(peek, "Erro sintático inesperado: #{error.message}")
        synchronize(start_pos)
      end
    end

    @parsed = true
    @ast = ProgramNode.new(declarations: declarations)
  end

  alias ast parse

  def errors
    parse unless @parsed
    @errors
  end

  def valid?
    parse unless @parsed
    @errors.empty?
  end

  private

  def parse_statement
    return parse_declaration if check?(:TIPO_DADO)
    return parse_assignment if check?(:IDENTIFICADOR)

    raise_syntax_error(peek, "Comando inválido ou inesperado '#{peek.lexeme}'")
  end

  def parse_declaration
    type_token = advance
    declarations = []

    loop do
      name_token = consume(:IDENTIFICADOR, "Esperado identificador após o tipo '#{type_token.lexeme}'")
      expression = match?(:OP_ATRIB) ? parse_expression : nil
      declarations << VarDeclNode.new(type_token: type_token, name_token: name_token, expression: expression)
      break unless match?(:VIRGULA)
    end

    consume(:PONTO_VIRGULA, "Esperado ';' após a declaração de '#{declarations.last.name_token.lexeme}'")
    declarations.size == 1 ? declarations.first : declarations
  end

  def parse_assignment
    target_token = advance
    consume(:OP_ATRIB, "Esperado '=' na atribuição para '#{target_token.lexeme}'")
    expression = parse_expression
    consume(:PONTO_VIRGULA, "Esperado ';' após a atribuição para '#{target_token.lexeme}'")
    AssignNode.new(target: target_token, expression: expression)
  end

  def parse_expression
    node = parse_term
    while match?(:OP_SOMA, :OP_SUB)
      operator_token = previous
      right = parse_term
      node = BinaryOpNode.new(left: node, operator_token: operator_token, right: right)
    end
    node
  end

  def parse_term
    node = parse_factor
    while match?(:OP_MULT, :OP_DIV, :OP_MOD)
      operator_token = previous
      right = parse_factor
      node = BinaryOpNode.new(left: node, operator_token: operator_token, right: right)
    end
    node
  end

  def parse_factor
    return NumberNode.new(token: previous) if match?(:NUMERO)
    return StringNode.new(token: previous) if match?(:LITERAL_STRING)
    return CharNode.new(token: previous) if match?(:LITERAL_CHAR)
    return IdentifierNode.new(token: previous) if match?(:IDENTIFICADOR)

    if match?(:PARENTESE_ESQ)
      open_paren = previous
      expression = parse_expression
      consume(
        :PARENTESE_DIR,
        "Esperado ')' para fechar '(' aberto na linha #{open_paren.line}, coluna #{open_paren.column}"
      )
      return expression
    end

    found = at_end? ? 'fim do arquivo' : "'#{peek.lexeme}'"
    raise_syntax_error(peek, "Expressão esperada, mas foi encontrado #{found}")
  end

  def raise_syntax_error(token, message)
    record_error(token, message)
    raise SyntaxAbort
  end

  def record_error(token, message)
    @errors << ParseError.new(message, token.line, token.column, token)
  end

  def synchronize(start_pos)
    advance if @pos == start_pos && !at_end?

    until at_end?
      return if previous.type == :PONTO_VIRGULA
      return if check?(:TIPO_DADO)

      advance
    end
  end

  def build_eof(tokens)
    last = tokens.last
    return Token.new(:EOF, '', 1, 1) if last.nil?

    Token.new(:EOF, '', last.line, last.column + last.lexeme.to_s.length)
  end
end
