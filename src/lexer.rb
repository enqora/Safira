# frozen_string_literal: true

Token = Struct.new(:type, :lexeme, :line, :column) do
  def to_s = format("[Linha %2d, Col %2d]  TIPO: %-16s | LEXEMA: '%s'", line, column, type, lexeme)
end

SymbolEntry = Struct.new(:name, :type, :line, :order) do
  def to_s = "#{order}. #{name} (#{type || 'indefinido'}) [Linha #{line}]"
end

LexicalError = Struct.new(:message, :line, :column, :char) do
  def to_s = "[Linha #{line}, Col #{column}] Erro Léxico: #{message}"
end

class Lexer
  KEYWORDS = {
    'int' => :TIPO_DADO,
    'float' => :TIPO_DADO,
    'char' => :TIPO_DADO,
    'double' => :TIPO_DADO,
    'void' => :TIPO_DADO,
    'if' => :KW_IF,
    'else' => :KW_ELSE,
    'while' => :KW_WHILE,
    'for' => :KW_FOR,
    'return' => :KW_RETURN
  }.freeze

  SINGLE_CHAR_TOKENS = {
    '=' => :OP_ATRIB,
    '+' => :OP_SOMA,
    '-' => :OP_SUB,
    '*' => :OP_MULT,
    '/' => :OP_DIV,
    '%' => :OP_MOD,
    ';' => :PONTO_VIRGULA,
    '(' => :PARENTESE_ESQ,
    ')' => :PARENTESE_DIR,
    '{' => :CHAVE_ESQ,
    '}' => :CHAVE_DIR,
    ',' => :VIRGULA,
    '<' => :OP_MENOR,
    '>' => :OP_MAIOR,
    '!' => :OP_NAO,
    '[' => :COLCHETE_ESQ,
    ']' => :COLCHETE_DIR
  }.freeze

  TWO_CHAR_TOKENS = {
    '+=' => :OP_SOMA_ATRIB,
    '-=' => :OP_SUB_ATRIB,
    '*=' => :OP_MULT_ATRIB,
    '/=' => :OP_DIV_ATRIB,
    '%=' => :OP_MOD_ATRIB,
    '==' => :OP_IGUAL,
    '!=' => :OP_DIFERENTE,
    '<=' => :OP_MENOR_IGUAL,
    '>=' => :OP_MAIOR_IGUAL,
    '&&' => :OP_E_LOGICO,
    '||' => :OP_OU_LOGICO,
    '++' => :OP_INC,
    '--' => :OP_DEC
  }.freeze

  IDENTIFIER = /\G[a-zA-Z_][a-zA-Z0-9_]*/
  NUMBER     = /\G(?:\d+\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+|\d+)/

  def initialize(source)
    @source = source.to_s
    @tokens = nil
    @symbols = []
    @errors = []
    @line = 1
    @column = 1
    @pos = 0
    @line_start = 0
  end

  def tokenize
    return @tokens if @tokens

    @tokens = []
    while @pos < @source.length
      next if skip_whitespace
      next if skip_directive
      next if skip_comment
      next if read_string
      next if read_number
      next if read_identifier
      next if read_operator

      char = @source[@pos]
      @errors << LexicalError.new("Caractere desconhecido '#{char}'", @line, @column, char)
      advance
    end

    @tokens
  end

  def tokens = tokenize
  def valid? = errors.empty?

  def symbols
    tokenize
    @symbols
  end

  def errors
    tokenize
    @errors
  end

  private

  def advance(n = 1)
    @pos += n
    @column += n
  end

  def advance_char
    if newline?(@source[@pos])
      @pos += (@source[@pos, 2] == "\r\n" ? 2 : 1)
      @line += 1
      @column = 1
      @line_start = @pos
    else
      advance
    end
  end

  def newline?(char) = char == "\n" || char == "\r"

  def emit(type, lexeme)
    @tokens << Token.new(type, lexeme, @line, @column)
    advance(lexeme.length)
  end

  def register_symbol(name, line)
    return if @symbols.any? { |s| s.name == name }

    @symbols << SymbolEntry.new(name, nil, line, @symbols.size + 1)
  end

  def skip_whitespace
    char = @source[@pos]
    return false unless char == ' ' || char == "\t" || newline?(char)

    advance_char
    true
  end

  # Ignora diretivas (#include, #define) quando '#' é o primeiro caractere útil da linha.
  def skip_directive
    return false unless @source[@pos] == '#'
    return false unless @source[@line_start...@pos].match?(/\A[ \t]*\z/)

    advance while @pos < @source.length && !newline?(@source[@pos])
    true
  end

  def skip_comment
    return false unless @source[@pos] == '/'

    case @source[@pos + 1]
    when '/'
      advance(2)
      advance while @pos < @source.length && !newline?(@source[@pos])
      true
    when '*'
      start_line = @line
      start_col = @column
      advance(2)
      while @pos < @source.length
        if @source[@pos, 2] == '*/'
          advance(2)
          return true
        end
        advance_char
      end
      @errors << LexicalError.new('Comentário de bloco não finalizado', start_line, start_col, '/*')
      true
    else
      false
    end
  end

  def read_string
    quote = @source[@pos]
    return false unless quote == '"' || quote == "'"

    start_line = @line
    start_col = @column
    start_pos = @pos
    advance

    while @pos < @source.length && !newline?(@source[@pos])
      # Barra antes da quebra não escapa nada, senão a contagem de linha se perde.
      if @source[@pos] == '\\' && @pos + 1 < @source.length && !newline?(@source[@pos + 1])
        advance(2)
      elsif @source[@pos] == quote
        advance
        type = quote == "'" ? :LITERAL_CHAR : :LITERAL_STRING
        @tokens << Token.new(type, @source[start_pos...@pos], start_line, start_col)
        return true
      else
        advance
      end
    end

    @errors << LexicalError.new('Literal de texto não finalizado', start_line, start_col, quote)
    true
  end

  def read_number
    match = @source.match(NUMBER, @pos)
    return false unless match

    lexeme = match[0]
    if (suffix = @source.match(IDENTIFIER, @pos + lexeme.length))
      bad = lexeme + suffix[0]
      @errors << LexicalError.new("Identificador inválido '#{bad}' (não pode começar com dígito)", @line, @column, bad)
      advance(bad.length)
    else
      emit(:NUMERO, lexeme)
    end
    true
  end

  def read_identifier
    match = @source.match(IDENTIFIER, @pos)
    return false unless match

    lexeme = match[0]
    type = KEYWORDS.fetch(lexeme, :IDENTIFICADOR)
    register_symbol(lexeme, @line) if type == :IDENTIFICADOR
    emit(type, lexeme)
    true
  end

  def read_operator
    if (type = TWO_CHAR_TOKENS[@source[@pos, 2]])
      emit(type, @source[@pos, 2])
    elsif (type = SINGLE_CHAR_TOKENS[@source[@pos]])
      emit(type, @source[@pos])
    end
  end
end
