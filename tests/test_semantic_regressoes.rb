# frozen_string_literal: true

require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/semantic'

GREEN  = "\e[32m"
RED    = "\e[31m"
BLUE   = "\e[34m"
YELLOW = "\e[33m"
RESET  = "\e[0m"

$falhas = 0

def assert(condition, message)
  if condition
    puts "  #{GREEN}✔#{RESET} #{message}"
  else
    puts "  #{RED}✖ [FALHA]#{RESET} #{message}"
    $falhas += 1
  end
end

def analyze(source)
  lexer = Lexer.new(source)
  parser = Parser.new(lexer.tokens)
  semantic = SemanticAnalyzer.new(parser.parse, lexer.symbols)
  semantic.analyze
  semantic
end

def kinds(semantic) = semantic.errors.map(&:kind)

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Regressões da Semântica (src/semantic.rb)           #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

puts "#{YELLOW}[1] Atribuição composta com variável não declarada#{RESET}"
s1 = analyze('y += 1;')
assert(kinds(s1) == %i[undeclared_variable], "'y += 1;' gera exatamente 1 erro (obtido: #{kinds(s1)})")
s1b = analyze('x = x + 1;')
assert(kinds(s1b) == %i[undeclared_variable undeclared_variable] && s1b.errors.map(&:column) == [1, 5],
       "'x = x + 1;' continua gerando 2 erros, colunas 1 e 5 (obtido: #{s1b.errors.map(&:column)})")
s1c = analyze("int main() { return 0; }\nmain *= 2;")
assert(kinds(s1c) == %i[invalid_operation], "'main *= 2;' gera 1 erro de função usada como variável (obtido: #{kinds(s1c)})")

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DE REGRESSÃO DA SEMÂNTICA FORAM APROVADOS!    #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
