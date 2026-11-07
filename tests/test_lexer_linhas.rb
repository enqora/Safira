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
puts "#{BLUE}  SAFIRA — Linhas após barra invertida em literais (lexer)      #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

puts "#{YELLOW}[1] Barra invertida antes da quebra de linha#{RESET}"
["\n", "\r\n", "\r"].each do |newline|
  lexer = Lexer.new(%(char* s = "abc\\#{newline}int @ = 1;))
  unfinished = lexer.errors.find { |e| e.message == 'Literal de texto não finalizado' }
  at_sign = lexer.errors.find { |e| e.char == '@' }
  label = newline.inspect
  assert(unfinished && unfinished.line == 1 && unfinished.column == 11,
         "#{label}: literal não finalizado na linha 1, coluna 11")
  assert(at_sign && at_sign.line == 2 && at_sign.column == 5,
         "#{label}: '@' reportado na linha 2, coluna 5 (obtido: #{at_sign && [at_sign.line, at_sign.column]})")
  int_token = lexer.tokens.find { |t| t.lexeme == 'int' }
  assert(int_token && int_token.line == 2 && int_token.column == 1, "#{label}: 'int' da linha 2 vira token na posição certa")
end

puts "\n#{YELLOW}[2] Barra invertida como último caractere do arquivo#{RESET}"
lexer = Lexer.new(%(int x;\nchar* s = "abc\\))
assert(lexer.errors.map(&:message) == ['Literal de texto não finalizado'],
       "Barra no fim gera só o erro de literal não finalizado (obtido: #{lexer.errors.map(&:message)})")
assert(lexer.errors.first.line == 2, 'Erro aponta a linha 2')
assert(Lexer.new(%("\\)).errors.size == 1, 'Literal só com aspas e barra não trava nem estoura')

puts "\n#{YELLOW}[3] Escapes comuns continuam funcionando#{RESET}"
escaped = Lexer.new(%(x = "a\\"b\\\\"; y = '\\n';))
assert(escaped.valid?, 'Escapes de aspas, barra e \n não geram erro')
assert(escaped.tokens.map(&:type).count { |t| t == :LITERAL_STRING || t == :LITERAL_CHAR } == 2,
       'Literais com escape viram um token cada')

puts "\n#{GREEN}================================================================#{RESET}"
puts "#{GREEN}  TODOS OS TESTES DE LINHA DO LEXER FORAM APROVADOS!            #{RESET}"
puts "#{GREEN}================================================================#{RESET}"
