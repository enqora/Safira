# frozen_string_literal: true

# Representa cada unidade léxica identificada no código-fonte.
# Atende ao item "Lista de Tokens" do barema (tipo, lexema, linha e coluna).
Token = Struct.new(:type, :lexeme, :line, :column) do
  def to_s
    format(
      '[Linha %<line>2d, Col %<col>2d]  TIPO: %<type>-16s | LEXEMA: %<lexeme>p',
      line: line,
      col: column,
      type: type.to_s,
      lexeme: lexeme
    )
  end
end

# Representa uma entrada única na Tabela de Símbolos.
# Armazena identificadores, tipo, linha e ordem cronológica de inserção (Item I do Barema).
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

# Armazena inconsistências léxicas sem interromper a execução do compilador.
LexicalError = Struct.new(:message, :line, :column, :char) do
  def to_s
    "[Linha #{line}, Col #{column}] Erro Léxico: #{message}"
  end
end

# ==============================================================================
# CLASSE PRINCIPAL: Lexer
# ==============================================================================
class Lexer
  attr_reader :source

  # Palavras reservadas e tipos primitivos reconhecidos pela linguagem
  KEYWORDS = {
    'int' => :TIPO_DADO,
    'float' => :TIPO_DADO,
    'char' => :TIPO_DADO,
    'double' => :TIPO_DADO
  }.freeze

  # Mapeamento de operadores e símbolos de pontuação de caractere único
  SINGLE_CHAR_TOKENS = {
    '=' => :OP_ATRIB,
    '+' => :OP_SOMA,
    '-' => :OP_SUB,
    '*' => :OP_MULT,
    '/' => :OP_DIV,
    ';' => :PONTO_VIRGULA,
    '(' => :PARENTESE_ESQ,
    ')' => :PARENTESE_DIR,
    '{' => :CHAVE_ESQ,
    '}' => :CHAVE_DIR,
    ',' => :VIRGULA
  }.freeze

  # Expressões regulares ancoradas (\G) para casar a partir da posição atual do cursor
  IDENTIFIER_REGEX = /\G([a-zA-Z_][a-zA-Z0-9_]*)/.freeze
  NUMBER_REGEX     = /\G(\d+\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+|\d+)/.freeze

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

  # Varre o código caractere a caractere gerando tokens e preenchendo a Tabela de Símbolos
  def tokenize
    return @tokens if @tokenized

    while @pos < @source.length
      # Tenta reconhecer cada padrão léxico em ordem de precedência
      next if handle_newlines_and_spaces
      next if handle_comments
      next if handle_string_literals
      next if handle_numbers
      next if handle_identifiers_and_keywords
      next if handle_operators_and_delimiters

      # Se nenhum padrão casar, captura o caractere desconhecido como erro léxico
      handle_unknown_character
    end

    @tokenized = true
    @tokens
  end

  # Retorna a lista completa de tokens processados
  def tokens
    tokenize unless @tokenized
    @tokens
  end

  # Retorna a Tabela de Símbolos gerada na análise
  def symbols
    tokenize unless @tokenized
    @symbols
  end

  alias symbol_table symbols

  # Retorna a lista de erros léxicos encontrados
  def errors
    tokenize unless @tokenized
    @errors
  end

  # Indica se a análise léxica ocorreu com 100% de assertividade (sem erros)
  def valid?
    tokenize unless @tokenized
    @errors.empty?
  end

  # Localiza um símbolo existente na tabela pelo nome
  def find_symbol(name)
    symbols.find { |s| s.name == name }
  end

  # Verifica se determinado identificador já foi registrado na tabela
  def symbol?(name)
    !find_symbol(name).nil?
  end

  alias has_symbol? symbol?

  private

  # Registra identificadores únicos garantindo a ordem cronológica de inserção
  def register_symbol(name, line)
    return if @symbols.any? { |s| s.name == name }

    order = @symbols.size + 1
    @symbols << SymbolEntry.new(name, nil, line, order)
  end

  # Ignora espaços em branco e atualiza a contagem de linhas e colunas
  def handle_newlines_and_spaces
    char = @source[@pos]

    if char == "\n"
      advance_newline(1)
      true
    elsif char == "\r"
      advance_newline(@pos + 1 < @source.length && @source[@pos + 1] == "\n" ? 2 : 1)
      true
    elsif [' ', "\t"].include?(char)
      @column += 1
      @pos += 1
      true
    else
      false
    end
  end

  def advance_newline(offset)
    @line += 1
    @column = 1
    @pos += offset
  end

  # Identifica e descarta comentários de linha (//) e de bloco (/* ... */)
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

      advance_comment_char
    end

    @errors << LexicalError.new('Comentário de bloco não finalizado', start_line, start_col, '/*') unless closed
    true
  end

  def advance_comment_char
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

  # Processa literais de texto ("..." e '...'), suportando caracteres de escape
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
      @tokens << Token.new(:LITERAL_STRING, full_lexeme, start_line, start_col)
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

  # Processa literais numéricos (inteiros e ponto flutuante com notação científica)
  def handle_numbers
    match = @source.match(NUMBER_REGEX, @pos)
    return false unless match

    lexeme = match[1]
    @tokens << Token.new(:NUMERO, lexeme, @line, @column)
    @column += lexeme.length
    @pos += lexeme.length
    true
  end

  # Reconhece identificadores e diferencia de palavras-chave da linguagem
  def handle_identifiers_and_keywords
    match = @source.match(IDENTIFIER_REGEX, @pos)
    return false unless match

    lexeme = match[1]
    start_line = @line
    start_col = @column

    if KEYWORDS.key?(lexeme)
      @tokens << Token.new(:TIPO_DADO, lexeme, start_line, start_col)
    else
      @tokens << Token.new(:IDENTIFICADOR, lexeme, start_line, start_col)
      register_symbol(lexeme, start_line)
    end

    @column += lexeme.length
    @pos += lexeme.length
    true
  end

  # Reconhece operadores matemáticos, operador de atribuição e delimitadores
  def handle_operators_and_delimiters
    char = @source[@pos]
    return false unless SINGLE_CHAR_TOKENS.key?(char)

    type = SINGLE_CHAR_TOKENS[char]
    @tokens << Token.new(type, char, @line, @column)
    @column += 1
    @pos += 1
    true
  end

  # Captura caracteres inválidos sem interromper o fluxo léxico
  def handle_unknown_character
    char = @source[@pos]
    @errors << LexicalError.new("Caractere desconhecido '#{char}'", @line, @column, char)
    @pos += 1
    @column += 1
  end
end
