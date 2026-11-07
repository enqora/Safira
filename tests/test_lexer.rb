# frozen_string_literal: true

require_relative '../src/lexer'

GREEN = "\e[32m"
RED = "\e[31m"
BLUE = "\e[34m"
YELLOW = "\e[33m"
RESET = "\e[0m"

def assert(condition, message)
  if condition
    puts "  #{GREEN}✔#{RESET} #{message}"
  else
    puts "  #{RED}✖ [FALHA]#{RESET} #{message}"
    exit 1
  end
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes Unitários do Lexer (src/lexer.rb)              #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# Teste 1: Declarações e Identificadores na Tabela de Símbolos
puts "#{YELLOW}[1] Teste de Declaração de Variáveis e Tabela de Símbolos#{RESET}"
code1 = <<~C
  int idade = 25;
  float salario = 1250.75;
  char genero = 'M';
  double precisao = 0.00001;
C

lexer1 = Lexer.new(code1)
tokens1 = lexer1.tokenize
symbols1 = lexer1.symbols

assert(lexer1.valid?, 'Nenhum erro léxico deve ocorrer no Teste 1')
assert(tokens1.size == 20, "Total de tokens deve ser 20 (obtido: #{tokens1.size})")
assert(symbols1.size == 4, "Total de símbolos deve ser 4 (obtido: #{symbols1.size})")
assert(symbols1.map(&:name) == %w[idade salario genero precisao], 'Identificadores cadastrados corretamente')
assert(symbols1.all? { |s| s.type.nil? }, 'Tipos na tabela de símbolos são mantidos nil pelo Lexer (delegados à semântica)')
assert(symbols1.map(&:order) == [1, 2, 3, 4], 'Ordem cronológica incremental correta')

# Teste 2: Múltiplas Variáveis e Reatribuição (sem duplicação)
puts "\n#{YELLOW}[2] Teste de Múltiplas Variáveis e Não-duplicação de Símbolos#{RESET}"
code2 = <<~C
  int a, b;
  a = 10;
  b = a + 5 * 2;
  total = a / 2;
C

lexer2 = Lexer.new(code2)
tokens2 = lexer2.tokenize
symbols2 = lexer2.symbols

assert(lexer2.valid?, 'Nenhum erro léxico deve ocorrer no Teste 2')
assert(symbols2.size == 3, "Total de símbolos deve ser 3 (a, b, total) (obtido: #{symbols2.size})")
assert(symbols2.map(&:name) == %w[a b total], 'Símbolos a, b e total registrados na ordem')
assert(symbols2.map(&:order) == [1, 2, 3], 'Ordem cronológica correta')

# Teste 3: Comentários de Bloco e Linha (Fluxo e Rastreamento de Posição)
puts "\n#{YELLOW}[3] Teste de Comentários de Bloco e Linha#{RESET}"
code3 = <<~C
  /* Comentario de bloco no inicio */
  // Comentario de linha
  int x = 5; /* Comentario
  de bloco */ float y = 10.0;
  /* Bloco final */
C

lexer3 = Lexer.new(code3)
tokens3 = lexer3.tokenize

assert(lexer3.valid?, 'Comentários não geram erro léxico nem tokens fantasmas')
token_int = tokens3.find { |t| t.type == :TIPO_DADO && t.lexeme == 'int' }
token_x = tokens3.find { |t| t.lexeme == 'x' }
token_float = tokens3.find { |t| t.type == :TIPO_DADO && t.lexeme == 'float' }
token_y = tokens3.find { |t| t.lexeme == 'y' }

assert(token_int.line == 3 && token_int.column == 1, "Posição de 'int' após comentários deve ser [3, 1] (obtido: [#{token_int.line}, #{token_int.column}])")
assert(token_x.line == 3 && token_x.column == 5, "Posição de 'x' deve ser [3, 5] (obtido: [#{token_x.line}, #{token_x.column}])")
assert(token_float.line == 4 && token_float.column == 13, "Posição de 'float' imediatamente após '*/' deve ser [4, 13] (obtido: [#{token_float.line}, #{token_float.column}])")
assert(token_y.line == 4 && token_y.column == 19, "Posição de 'y' deve ser [4, 19] (obtido: [#{token_y.line}, #{token_y.column}])")

# Teste 4: Captura de Caracteres Desconhecidos e Erros sem Exceção
puts "\n#{YELLOW}[4] Teste de Tratamento de Erros Léxicos Sem Travar#{RESET}"
code4 = <<~C
  int @var = 10;
  int #invalido;
  float ok = 1.5;
C

lexer4 = Lexer.new(code4)
tokens4 = lexer4.tokenize
errors4 = lexer4.errors

assert(!lexer4.valid?, 'Código com caracteres desconhecidos deve ser marcado como inválido')
assert(errors4.size == 2, "Devem ser capturados 2 erros léxicos (@ e #) (obtido: #{errors4.size})")
assert(errors4[0].line == 1 && errors4[0].column == 5, 'Primeiro erro na linha 1, coluna 5')
assert(errors4[1].line == 2 && errors4[1].column == 5, 'Segundo erro na linha 2, coluna 5')
assert(tokens4.any? { |t| t.lexeme == 'ok' }, 'Lexer continua tokenizando após erros sem lançar exceção')

# Teste 5: Operadores Relacionais, Lógicos e Delimitadores
puts "\n#{YELLOW}[5] Teste de Operadores Relacionais, Lógicos e Delimitadores#{RESET}"
code5 = 'a>=1&&b<=2||c!=d&&e==f;x=a>b;y=c<d;z=!w;v[0];'

lexer5 = Lexer.new(code5)
types5 = lexer5.tokens.map(&:type)

assert(lexer5.valid?, 'Nenhum erro léxico com os novos operadores')
assert(types5.include?(:OP_IGUAL) && types5.count(:OP_ATRIB) == 3, "'==' gera :OP_IGUAL e não dois :OP_ATRIB")
assert(types5.include?(:OP_MAIOR_IGUAL), "'>=' gera :OP_MAIOR_IGUAL")
assert(types5.include?(:OP_MENOR_IGUAL), "'<=' gera :OP_MENOR_IGUAL")
assert(types5.include?(:OP_DIFERENTE) && types5.count(:OP_NAO) == 1, "'!=' gera :OP_DIFERENTE e '!' isolado gera :OP_NAO")
assert(types5.count(:OP_E_LOGICO) == 2 && types5.count(:OP_OU_LOGICO) == 1, "'&&' e '||' geram operadores lógicos")
assert(types5.include?(:OP_MAIOR) && types5.include?(:OP_MENOR), "'>' e '<' isolados geram :OP_MAIOR e :OP_MENOR")
assert(types5.include?(:COLCHETE_ESQ) && types5.include?(:COLCHETE_DIR), "'[' e ']' geram colchetes")

expected_start = %i[IDENTIFICADOR OP_MAIOR_IGUAL NUMERO OP_E_LOGICO IDENTIFICADOR OP_MENOR_IGUAL NUMERO OP_OU_LOGICO]
assert(types5.first(8) == expected_start, "Sequência 'a>=1&&b<=2||' tokenizada na ordem correta")

token_b = lexer5.tokens.find { |t| t.lexeme == 'b' }
assert(token_b.column == 7, "Coluna de 'b' após dois operadores de 2 chars deve ser 7 (obtido: #{token_b.column})")

lexer5b = Lexer.new('a & b | c')
assert(lexer5b.errors.size == 2, "'&' e '|' isolados geram erro léxico (obtido: #{lexer5b.errors.size})")

# Teste 6: Palavras-chave de controle de fluxo e void
puts "\n#{YELLOW}[6] Teste de Palavras-chave (if, else, while, return, void)#{RESET}"
code6 = <<~C
  void main() {
    while (x > 0) { if (x == 1) { return; } else { x = x - 1; } }
  }
C

lexer6 = Lexer.new(code6)
types6 = lexer6.tokens.map(&:type)

assert(lexer6.valid?, 'Nenhum erro léxico no Teste 6')
assert(lexer6.tokens.first.type == :TIPO_DADO && lexer6.tokens.first.lexeme == 'void', "'void' gera :TIPO_DADO")
assert(%i[KW_IF KW_ELSE KW_WHILE KW_RETURN].all? { |k| types6.include?(k) }, 'if/else/while/return geram :KW_*')
assert(lexer6.symbols.map(&:name) == %w[main x],
       "Palavras-chave NÃO entram na tabela de símbolos (obtido: #{lexer6.symbols.map(&:name)})")

# Teste 7: char vs string, %, ++/--, identificador malformado e formatação
puts "\n#{YELLOW}[7] Teste de Literais, %, ++/--, '123var' e Formatação#{RESET}"
lexer7 = Lexer.new(%(char c = 'a'; x = "abc"; y = x % 2; i++; j--;))
types7 = lexer7.tokens.map(&:type)

assert(lexer7.valid?, 'Nenhum erro léxico no Teste 7')
assert(types7.include?(:LITERAL_CHAR) && types7.include?(:LITERAL_STRING), "'a' gera :LITERAL_CHAR e \"abc\" gera :LITERAL_STRING")
assert(types7.include?(:OP_MOD), "'%' gera :OP_MOD")
assert(types7.include?(:OP_INC) && types7.include?(:OP_DEC), "'++' e '--' geram :OP_INC e :OP_DEC")
assert(!types7.include?(:OP_SOMA) && !types7.include?(:OP_SUB), "'++'/'--' não viram dois '+'/'-'")

lexer7b = Lexer.new('int 123var = 5;')
assert(lexer7b.errors.size == 1 && lexer7b.errors.first.char == '123var', "'123var' gera um único erro léxico")
assert(lexer7b.errors.first.column == 5, "Erro de '123var' na coluna 5 (obtido: #{lexer7b.errors.first.column})")
assert(lexer7b.tokens.none? { |t| t.lexeme == 'var' }, "'var' não vira identificador fantasma")
assert(Lexer.new('x = 1.5e3;').valid?, 'Notação científica continua válida')

assert(Lexer.new('int').tokens.first.to_s.end_with?("LEXEMA: 'int'"), 'Token#to_s usa aspas simples (layout do AGENT.md)')

# Teste 8: atribuição composta e preservação dos operadores existentes
puts "\n#{YELLOW}[8] Teste de Atribuição Composta (+= e -=)#{RESET}"
lexer8 = Lexer.new('i+=2; i-=1;')
assert(lexer8.valid?, 'Atribuições compostas não geram erros léxicos')
assert(lexer8.tokens.map(&:type) == %i[
  IDENTIFICADOR OP_SOMA_ATRIB NUMERO PONTO_VIRGULA
  IDENTIFICADOR OP_SUB_ATRIB NUMERO PONTO_VIRGULA
], '+= e -= são reconhecidos como tokens únicos')
assert(lexer8.tokens.map(&:lexeme) == %w[i += 2 ; i -= 1 ;],
       'Lexemas das atribuições compostas são preservados')
assert(lexer8.tokens.map(&:column) == [1, 2, 4, 5, 7, 8, 10, 11],
       'Operadores compostos avançam a coluna em dois caracteres')
assert(Lexer.new('+ - = ++ -- + = - =').tokens.map(&:type) == %i[
  OP_SOMA OP_SUB OP_ATRIB OP_INC OP_DEC OP_SOMA OP_ATRIB OP_SUB OP_ATRIB
], 'Operadores existentes e operadores separados por espaços mantêm seus tokens')

# Teste 9: diretivas de uma linha
puts "\n#{YELLOW}[9] Teste de Diretivas de Pré-processador#{RESET}"
lexer9 = Lexer.new("#include <stdio.h>\r\n \t#define LIMITE 10\r\n  int x = 2;\r\n#define FIM 0")
assert(lexer9.valid?, 'Diretivas são ignoradas, inclusive no fim do arquivo')
assert(lexer9.tokens.map(&:lexeme) == %w[int x = 2 ;], 'Diretivas não geram tokens')
assert(lexer9.symbols.map(&:name) == ['x'], 'Diretivas não inserem símbolos')
assert(lexer9.tokens.first.line == 3 && lexer9.tokens.first.column == 3,
       'Linha e coluna após diretivas com CRLF são preservadas')
["\n", "\r"].each do |newline|
  token = Lexer.new("#define X 1#{newline}int x;").tokens.first
  assert(token.line == 2 && token.column == 1, 'Posição após diretiva respeita LF e CR')
end
assert(Lexer.new(%q{"#include <stdio.h>" '#'}).tokens.map(&:type) == %i[LITERAL_STRING LITERAL_CHAR],
       '# dentro de literais é preservado')
assert(Lexer.new("// #include <stdio.h>\n/* #define X 1 */ int x;").valid?,
       '# dentro de comentários continua sendo ignorado')
assert(Lexer.new('int x; #define X 1').errors.any? { |error| error.char == '#' },
       '# após código na mesma linha continua sendo inválido')

puts "\n#{GREEN}================================================================#{RESET}"
puts "#{GREEN}  TODOS OS TESTES UNITÁRIOS DO LEXER FORAM APROVADOS COM SUCESSO!#{RESET}"
puts "#{GREEN}================================================================#{RESET}"
