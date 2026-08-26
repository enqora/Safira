# frozen_string_literal: true

# Estrutura representativa de um Token
Token = Struct.new(:type, :lexeme, :line, :column) do
  def to_s
    format('[Linha %2d, Col %2d]  TIPO: %-16s | LEXEMA: %p', line, column, type, lexeme)
  end
end

# Estrutura representativa de uma entrada na Tabela de Símbolos
SymbolEntry = Struct.new(:name, :type, :line, :order) do
  def to_s
    format('%d. %s (%s) [Linha %d]', order, name, type || 'indefinido', line)
  end
end

# Estrutura representativa de um Erro Léxico
LexicalError = Struct.new(:message, :line, :column, :char) do
  def to_s
    "[Linha #{line}, Col #{column}] Erro Léxico: #{message}"
  end
end

# Analisador Léxico (Lexer) do Safira em Ruby puro
class Lexer
  attr_reader :source, :tokens, :symbols, :errors

  # Palavras-chave / Tipos primitivos suportados
  KEYWORDS = {
    'int' => :TIPO_DADO,
    'float' => :TIPO_DADO,
    'char' => :TIPO_DADO,
    'double' => :TIPO_DADO
  }.freeze

  # Operadores de único caractere e delimitadores
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

  # Regex para identificadores (padrão C: inicia com letra ou _ seguido de alfanuméricos ou _)
  IDENTIFIER_REGEX = /\G([a-zA-Z_][a-zA-Z0-9_]*)/

  # Regex para números (decimais/float com prioridade sobre inteiros)
  NUMBER_REGEX = /\G(\d+\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+|\d+)/

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

  # Executa a análise léxica completa do código-fonte
  def tokenize
    return @tokens if @tokenized

    last_type_seen = nil

    while @pos < @source.length
      char = @source[@pos]

      # 1. Quebras de linha (\n, \r\n, \r)
      if char == "\n"
        @line += 1
        @column = 1
        @pos += 1
        next
      elsif char == "\r"
        @pos += (@pos + 1 < @source.length && @source[@pos + 1] == "\n" ? 2 : 1)
        @line += 1
        @column = 1
        next
      end

      # 2. Espaços em branco e tabulações
      if char == ' ' || char == "\t"
        @column += 1
        @pos += 1
        next
      end

      # 3. Comentários (linha '//' e bloco '/* ... */')
      if char == '/' && @pos + 1 < @source.length
        next_char = @source[@pos + 1]

        if next_char == '/'
          # Comentário de linha única
          @pos += 2
          @column += 2
          while @pos < @source.length && @source[@pos] != "\n" && @source[@pos] != "\r"
            @pos += 1
            @column += 1
          end
          next
        elsif next_char == '*'
          # Comentário de bloco
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
            elsif @source[@pos] == "\n"
              @line += 1
              @column = 1
              @pos += 1
            elsif @source[@pos] == "\r"
              @pos += (@pos + 1 < @source.length && @source[@pos + 1] == "\n" ? 2 : 1)
              @line += 1
              @column = 1
            else
              @column += 1
              @pos += 1
            end
          end

          unless closed
            @errors << LexicalError.new('Comentário de bloco não finalizado', start_line, start_col, '/*')
          end
          next
        end
      end

      # 4. Literais de String e Caractere ("..." e '...')
      if char == '"' || char == "'"
        quote_char = char
        start_line = @line
        start_col = @column
        start_pos = @pos
        @pos += 1
        @column += 1
        closed = false

        while @pos < @source.length
          curr = @source[@pos]
          if curr == '\\' && @pos + 1 < @source.length
            @pos += 2
            @column += 2
          elsif curr == quote_char
            @pos += 1
            @column += 1
            closed = true
            break
          elsif curr == "\n" || curr == "\r"
            # Quebra de linha dentro de literal não finalizado
            break
          else
            @pos += 1
            @column += 1
          end
        end

        if closed
          full_lexeme = @source[start_pos...@pos]
          @tokens << Token.new(:LITERAL_STRING, full_lexeme, start_line, start_col)
          last_type_seen = nil
        else
          @errors << LexicalError.new('Literal de texto não finalizado', start_line, start_col, quote_char)
        end
        next
      end

      # 5. Números (Floats e Inteiros)
      if (match = @source.match(NUMBER_REGEX, @pos))
        lexeme = match[1]
        @tokens << Token.new(:NUMERO, lexeme, @line, @column)
        @column += lexeme.length
        @pos += lexeme.length
        last_type_seen = nil
        next
      end

      # 6. Identificadores e Palavras-Chave
      if (match = @source.match(IDENTIFIER_REGEX, @pos))
        lexeme = match[1]
        start_line = @line
        start_col = @column

        if KEYWORDS.key?(lexeme)
          @tokens << Token.new(:TIPO_DADO, lexeme, start_line, start_col)
          last_type_seen = lexeme
        else
          @tokens << Token.new(:IDENTIFICADOR, lexeme, start_line, start_col)
          register_symbol(lexeme, last_type_seen, start_line)
          last_type_seen = nil
        end

        @column += lexeme.length
        @pos += lexeme.length
        next
      end

      # 7. Operadores e Delimitadores
      if SINGLE_CHAR_TOKENS.key?(char)
        type = SINGLE_CHAR_TOKENS[char]
        @tokens << Token.new(type, char, @line, @column)
        last_type_seen = nil if char == ';'
        @column += 1
        @pos += 1
        next
      end

      # 8. Caracteres Desconhecidos / Inválidos
      @errors << LexicalError.new("Caractere desconhecido '#{char}'", @line, @column, char)
      @pos += 1
      @column += 1
    end

    @tokenized = true
    @tokens
  end

  # Acesso aos tokens processados
  def tokens
    tokenize unless @tokenized
    @tokens
  end

  # Acesso à Tabela de Símbolos
  def symbols
    tokenize unless @tokenized
    @symbols
  end

  alias symbol_table symbols

  # Acesso aos erros léxicos encontrados
  def errors
    tokenize unless @tokenized
    @errors
  end

  # Indica se a análise léxica ocorreu sem erros
  def valid?
    tokenize unless @tokenized
    @errors.empty?
  end

  # Busca de símbolo por nome na Tabela de Símbolos
  def find_symbol(name)
    symbols.find { |s| s.name == name }
  end

  # Verifica se um símbolo já existe na Tabela de Símbolos
  def has_symbol?(name)
    !find_symbol(name).nil?
  end

  private

  # Registra ou atualiza um símbolo na Tabela de Símbolos
  def register_symbol(name, type, line)
    existing = @symbols.find { |s| s.name == name }
    if existing
      existing.type ||= type if type
    else
      order = @symbols.size + 1
      @symbols << SymbolEntry.new(name, type, line, order)
    end
  end
end
