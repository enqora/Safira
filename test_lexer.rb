# frozen_string_literal: true

require_relative 'src/lexer'

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

# Teste 1: Declarações e Tipos Primitivos
puts "#{YELLOW}[1] Teste de Declaração de Variáveis e Tipos Primitivos#{RESET}"
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
assert(symbols1.map(&:type) == %w[int float char double], 'Tipos cadastrados corretamente na tabela de símbolos')
assert(symbols1.map(&:order) == [1, 2, 3, 4], 'Ordem cronológica incremental correta')

# Teste 2: Reatribuição, Expressões e Não-duplicação na Tabela de Símbolos
puts "\n#{YELLOW}[2] Teste de Expressões e Não-duplicação de Símbolos#{RESET}"
code2 = <<~C
  int x = 10;
  x = x + 5 * 2;
  total = x / 2;
C

lexer2 = Lexer.new(code2)
tokens2 = lexer2.tokenize
symbols2 = lexer2.symbols

assert(lexer2.valid?, 'Nenhum erro léxico deve ocorrer no Teste 2')
assert(symbols2.size == 2, 'Não deve haver símbolos duplicados')
assert(symbols2[0].name == 'x' && symbols2[0].type == 'int', 'Símbolo x mantém tipo declarado')
assert(symbols2[1].name == 'total' && symbols2[1].type.nil?, 'Símbolo total sem declaração tem tipo nil')
assert(symbols2[1].order == 2, 'Ordem do símbolo total é 2')

# Teste 3: Comentários e Precisão de Linha / Coluna
puts "\n#{YELLOW}[3] Teste de Comentários e Rastreamento de Linha/Coluna#{RESET}"
code3 = <<~C
  // Comentario de linha inicial
  int x = 5; /* Comentario
  de bloco */ float y = 10.0;
C

lexer3 = Lexer.new(code3)
tokens3 = lexer3.tokenize

assert(lexer3.valid?, 'Comentários não geram erro léxico nem tokens espúrios')
token_x = tokens3.find { |t| t.lexeme == 'x' }
token_y = tokens3.find { |t| t.lexeme == 'y' }

assert(token_x.line == 2 && token_x.column == 5, "Posição de x deve ser [2, 5] (obtido: [#{token_x.line}, #{token_x.column}])")
assert(token_y.line == 3 && token_y.column == 19, "Posição de y após comentário multilinhas deve ser precisa [3, 19] (obtido: [#{token_y.line}, #{token_y.column}])")

# Teste 4: Captura de Caracteres Desconhecidos e Erros sem Exceção
puts "\n#{YELLOW}[4] Teste de Tratamento de Erros Léxicos Sem Travar#{RESET}"
code4 = <<~C
  int @var = 10;
  #invalido
  float ok = 1.5;
C

lexer4 = Lexer.new(code4)
tokens4 = lexer4.tokenize
errors4 = lexer4.errors

assert(!lexer4.valid?, 'Código com caracteres desconhecidos deve ser marcado como inválido')
assert(errors4.size == 2, "Devem ser capturados 2 erros léxicos (@ e #) (obtido: #{errors4.size})")
assert(errors4[0].line == 1 && errors4[0].column == 5, 'Primeiro erro na linha 1, coluna 5')
assert(errors4[1].line == 2 && errors4[1].column == 1, 'Segundo erro na linha 2, coluna 1')
assert(tokens4.any? { |t| t.lexeme == 'ok' }, 'Lexer continua tokenizando após erros sem lançar exceção')

puts "\n#{GREEN}================================================================#{RESET}"
puts "#{GREEN}  TODOS OS TESTES UNITÁRIOS DO LEXER FORAM APROVADOS COM SUCESSO!#{RESET}"
puts "#{GREEN}================================================================#{RESET}"
