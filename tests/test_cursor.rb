# frozen_string_literal: true

require_relative '../src/lexer'
require_relative '../src/parser'

GREEN = "\e[32m"
RED   = "\e[31m"
BLUE  = "\e[34m"
YELLOW = "\e[33m"
RESET = "\e[0m"

$falhas = 0

def assert(condition, message)
  if condition
    puts "  #{GREEN}✔#{RESET} #{message}"
  else
    puts "  #{RED}✖ [FALHA]#{RESET} #{message}"
    $falhas += 1
  end
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Etapa 2: Cursor do Parser (src/parser.rb)            #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

tokens = Lexer.new('int x = 5;').tokens
parser = Parser.new(tokens)

# --- peek: olha sem consumir -------------------------------------------------
puts "#{YELLOW}[1] peek — olha o token atual SEM mover o cursor#{RESET}"
assert(parser.peek.lexeme == 'int', "peek devolve o 1o token ('int')")
assert(parser.peek.lexeme == 'int', 'peek chamado 2x devolve o MESMO token (nao consumiu)')
assert(parser.peek.type == :TIPO_DADO, 'peek devolve um Token completo, com .type')

# --- check?: testa o tipo sem consumir ---------------------------------------
puts "\n#{YELLOW}[2] check? — testa o tipo SEM mover o cursor#{RESET}"
assert(parser.check?(:TIPO_DADO) == true,  'check?(:TIPO_DADO) e true no inicio')
assert(parser.check?(:NUMERO) == false,    'check?(:NUMERO) e false no inicio')
assert(parser.peek.lexeme == 'int',        'check? NAO consumiu o token')

# --- at_end?: detecta o sentinela --------------------------------------------
puts "\n#{YELLOW}[3] at_end? — detecta o fim da entrada#{RESET}"
assert(parser.at_end? == false, 'at_end? e false no inicio')

# --- advance: consome e anda -------------------------------------------------
puts "\n#{YELLOW}[4] advance — devolve o token atual E anda o cursor#{RESET}"
t = parser.advance
assert(t.respond_to?(:lexeme), 'advance devolve um Token (nao o valor de @pos)')
assert(t.lexeme == 'int',      "advance devolve o token que estava sob o cursor ('int')")
assert(parser.peek.lexeme == 'x', "apos advance, peek passou para o proximo ('x')")

assert(parser.advance.lexeme == 'x', "advance devolve 'x'")
assert(parser.advance.lexeme == '=', "advance devolve '='")
assert(parser.advance.lexeme == '5', "advance devolve '5'")
assert(parser.advance.lexeme == ';', "advance devolve ';'")

# --- fim da entrada ----------------------------------------------------------
puts "\n#{YELLOW}[5] Sentinela :EOF — o cursor nao sai do array#{RESET}"
assert(parser.at_end? == true,   'at_end? e true apos consumir todos os tokens')
assert(!parser.peek.nil?,        'peek NUNCA devolve nil (sentinela funcionando)')
assert(parser.peek.type == :EOF, 'peek devolve o token :EOF no fim')

5.times { parser.advance }
assert(parser.peek.type == :EOF, 'advance repetido no fim nao estoura o array')
assert(!parser.peek.nil?,        'peek continua seguro apos advance extra')

# --- caso degenerado ---------------------------------------------------------
puts "\n#{YELLOW}[6] Entrada vazia — guard clause do build_eof#{RESET}"
vazio = Parser.new(Lexer.new('').tokens)
assert(vazio.at_end? == true,       'parser de arquivo vazio ja comeca em at_end?')
assert(vazio.peek.type == :EOF,     'peek de arquivo vazio devolve :EOF sem estourar')

# --- resultado ---------------------------------------------------------------
puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  ETAPA 2 COMPLETA — cursor funcionando!#{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificacao(oes) falhando. Continue.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
