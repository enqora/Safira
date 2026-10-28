# frozen_string_literal: true

Token = Struct.new(:type, :lexeme, :line, :column) do
  def to_s
    format(
      "[Linha %<line>2d, Col %<col>2d]  TIPO: %<type>-16s | LEXEMA: '%<lexeme>s'",
      line: line,
      col: column,
      type: type.to_s,
      lexeme: lexeme
    )
  end
end

SymbolEntry = Struct.new(:name, :type, :line, :order) do
  def to_s
    format(
      '%<order>d. %<name>s (%<type>s) [Linha %<line>d]',
      order: order,
      name: name,
      type: type || 'indefinido',
      line: line
    )
  end
end

LexicalError = Struct.new(:message, :line, :column, :char) do
  def to_s
    "[Linha #{line}, Col #{column}] Erro Léxico: #{message}"
  end
end

class Lexer
  attr_reader :source

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
    '==' => :OP_IGUAL,
    '!=' => :OP_DIFERENTE,
    '<=' => :OP_MENOR_IGUAL,
    '>=' => :OP_MAIOR_IGUAL,
    '&&' => :OP_E_LOGICO,
    '||' => :OP_OU_LOGICO,
    '++' => :OP_INC,
    '--' => :OP_DEC
  }.freeze

  IDENTIFIER_REGEX = /\G([a-zA-Z_][a-zA-Z0-9_]*)/.freeze
  NUMBER_REGEX     = /\G(\d+\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+|\d+)/.freeze
  MALFORMED_SUFFIX_REGEX = /\G[a-zA-Z_][a-zA-Z0-9_]*/.freeze

  def initialize(source)
    @source = source.to_s
    @tokens = []
    @symbols = []
    @errors = []
    @line = 1
    @column = 1
    @pos = 0
    @tokenized = false
  end

  def tokenize
    return @tokens if @tokenized

    while @pos < @source.length
      next if handle_newlines_and_spaces
      next if handle_comments
      next if handle_string_literals
      next if handle_numbers
      next if handle_identifiers_and_keywords
      next if handle_operators_and_delimiters

      handle_unknown_character
    end

    @tokenized = true
    @tokens
  end

  def tokens
    tokenize unless @tokenized
    @tokens
  end

  def symbols
    tokenize unless @tokenized
    @symbols
  end

  alias symbol_table symbols

  def errors
    tokenize unless @tokenized
    @errors
  end

  def valid?
    tokenize unless @tokenized
    @errors.empty?
  end

  def find_symbol(name)
    symbols.find { |s| s.name == name }
  end

  def symbol?(name)
    !find_symbol(name).nil?
  end

  alias has_symbol? symbol?

  private

  def register_symbol(name, line)
    return if @symbols.any? { |s| s.name == name }

    order = @symbols.size + 1
    @symbols << SymbolEntry.new(name, nil, line, order)
  end

  def handle_newlines_and_spaces
    return false unless ["\n", "\r", ' ', "\t"].include?(@source[@pos])

    advance_character
    true
  end

  def advance_newline(offset)
    @line += 1
    @column = 1
    @pos += offset
  end

  def handle_comments
    return false unless @source[@pos] == '/' && @pos + 1 < @source.length

    case @source[@pos + 1]
    when '/'
      skip_line_comment
      true
    when '*'
      skip_block_comment
      true
    else
      false
    end
  end

  def skip_line_comment
    @pos += 2
    @column += 2
    while @pos < @source.length && !["\n", "\r"].include?(@source[@pos])
      @pos += 1
      @column += 1
    end
  end

  def skip_block_comment
    start_line = @line
    start_col = @column
    @pos += 2
    @column += 2
    closed = false

    while @pos < @source.length
      if @source[@pos] == '*' && @pos + 1 < @source.length && @source[@pos + 1] == '/'
        @pos += 2
        @column += 2
        closed = true
        break
      end

      advance_character
    end

    @errors << LexicalError.new('Comentário de bloco não finalizado', start_line, start_col, '/*') unless closed
    true
  end

  def advance_character
    char = @source[@pos]
    if char == "\n"
      advance_newline(1)
    elsif char == "\r"
      advance_newline(@pos + 1 < @source.length && @source[@pos + 1] == "\n" ? 2 : 1)
    else
      @column += 1
      @pos += 1
    end
  end

  def handle_string_literals
    char = @source[@pos]
    return false unless ['"', "'"].include?(char)

    start_line = @line
    start_col = @column
    start_pos = @pos
    @pos += 1
    @column += 1

    closed = consume_string_body(char)

    if closed
      full_lexeme = @source[start_pos...@pos]
      type = char == "'" ? :LITERAL_CHAR : :LITERAL_STRING
      @tokens << Token.new(type, full_lexeme, start_line, start_col)
    else
      @errors << LexicalError.new('Literal de texto não finalizado', start_line, start_col, char)
    end
    true
  end

  def consume_string_body(quote_char)
    while @pos < @source.length
      curr = @source[@pos]
      if curr == '\\' && @pos + 1 < @source.length
        @pos += 2
        @column += 2
      elsif curr == quote_char
        @pos += 1
        @column += 1
        return true
      elsif ["\n", "\r"].include?(curr)
        break
      else
        @pos += 1
        @column += 1
      end
    end
    false
  end

  def handle_numbers
    match = @source.match(NUMBER_REGEX, @pos)
    return false unless match

    lexeme = match[1]
    suffix = @source.match(MALFORMED_SUFFIX_REGEX, @pos + lexeme.length)
    return report_malformed_identifier(lexeme + suffix[0]) if suffix

    emit_token(:NUMERO, lexeme)
  end

  def report_malformed_identifier(lexeme)
    @errors << LexicalError.new("Identificador inválido '#{lexeme}' (não pode começar com dígito)",
                                @line, @column, lexeme)
    @column += lexeme.length
    @pos += lexeme.length
    true
  end

  def handle_identifiers_and_keywords
    match = @source.match(IDENTIFIER_REGEX, @pos)
    return false unless match

    lexeme = match[1]
    token_type = KEYWORDS.fetch(lexeme, :IDENTIFICADOR)
    @tokens << Token.new(token_type, lexeme, @line, @column)
    register_symbol(lexeme, @line) if token_type == :IDENTIFICADOR

    @column += lexeme.length
    @pos += lexeme.length
    true
  end

  def handle_operators_and_delimiters
    pair = @source[@pos, 2]
    return emit_token(TWO_CHAR_TOKENS[pair], pair) if TWO_CHAR_TOKENS.key?(pair)

    char = @source[@pos]
    return emit_token(SINGLE_CHAR_TOKENS[char], char) if SINGLE_CHAR_TOKENS.key?(char)

    false
  end

  def emit_token(type, lexeme)
    @tokens << Token.new(type, lexeme, @line, @column)
    @column += lexeme.length
    @pos += lexeme.length
    true
  end

  def handle_unknown_character
    char = @source[@pos]
    @errors << LexicalError.new("Caractere desconhecido '#{char}'", @line, @column, char)
    @pos += 1
    @column += 1
  end
end
