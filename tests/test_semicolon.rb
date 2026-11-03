# frozen_string_literal: true

require 'stringio'
require_relative '../safira'

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

def parse_code(source)
  parser = Parser.new(Lexer.new(source).tokens)
  parser.parse
  parser
end

def positions(parser) = parser.errors.map { |e| [e.line, e.column] }

def run_cli(*args)
  out = StringIO.new
  err = StringIO.new
  code = SafiraCLI::Runner.run(args + ['--no-color'], out: out, err: err)
  [code, out.string, err.string]
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes de Ponto e Vírgula Ausente (src/parser.rb)     #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Cada tipo de comando sem ';'
puts "#{YELLOW}[1] Detecção de ';' Ausente em Cada Tipo de Comando#{RESET}"
casos = {
  "int a = 10\nint b = 20;" => "Esperado ';' após a declaração de 'a'",
  "int a = 1, b = 2\nx = 3;" => "Esperado ';' após a declaração de 'b'",
  "x = a + b\ny = 1;" => "Esperado ';' após a atribuição para 'x'",
  "i++\nj--;" => "Esperado ';' após 'i++'",
  "int f() {\n  return 0\n}" => "Esperado ';' após o 'return'",
  'for (i = 0 i < 3; i++) { }' => "Esperado ';' após a inicialização do 'for'",
  'for (i = 0; i < 3 i++) { }' => "Esperado ';' após a condição do 'for'"
}

casos.each do |codigo, mensagem|
  parser = parse_code(codigo)
  assert(parser.errors.size == 1 && parser.errors.first.message == mensagem,
         "#{codigo.lines.first.strip.inspect} → \"#{mensagem}\" (obtido: #{parser.errors.map(&:message)})")
end

assert(parse_code("int a = 1;\na = a + 1;\nint f() { return a; }").valid?, "Código com todos os ';' não gera erro")

# [2] Posição exata do erro
puts "\n#{YELLOW}[2] Posição: Linha do ';' Ausente e Coluna Logo Após o Último Token#{RESET}"
p2 = parse_code("int a = 10\nint b = 20;")
assert(positions(p2) == [[1, 11]], "Erro na linha 1, coluna 11 — não na linha 2 (obtido: #{positions(p2)})")
assert(p2.errors.first.lexeme.nil?, 'Erro de símbolo ausente não aponta para o token seguinte')

assert(positions(parse_code("x = a + b\ny = 1;")) == [[1, 10]], "'x = a + b' sem ';' aponta a coluna 10")
assert(positions(parse_code("int f() {\n  return 0\n}")) == [[2, 11]], "'return 0' sem ';' aponta linha 2, coluna 11")
assert(positions(parse_code('x = 1')) == [[1, 6]], "';' ausente no fim do arquivo aponta após o '1'")
assert(positions(parse_code('for (i = 0; i < 3 i++) { }')) == [[1, 19]],
       "No cabeçalho do 'for', o erro aponta o token inesperado (coluna 19)")

# [3] Recuperação: o comando seguinte não se perde
puts "\n#{YELLOW}[3] Recuperação: Comandos Seguintes São Preservados#{RESET}"
p3 = parse_code("int a = 10\nint b = 20;\na = a + b\nb = a * 2;")
assert(p3.errors.size == 2, "Dois ';' ausentes geram exatamente 2 erros (obtido: #{p3.errors.size})")
assert(p3.parse.declarations.size == 4, "Os 4 comandos continuam na AST (obtido: #{p3.parse.declarations.size})")
assert(p3.parse.declarations.last.is_a?(AssignNode) && p3.parse.declarations.last.target.lexeme == 'b',
       "Último comando 'b = a * 2;' preservado")

p3b = parse_code('{ x = 1 }')
assert(p3b.errors.size == 1 && p3b.parse.declarations.first.statements.size == 1,
       "';' ausente antes de '}' gera 1 erro e mantém o comando no bloco")

p3c = parse_code('if (a) x = 1 else x = 2;')
assert(p3c.errors.size == 1 && p3c.parse.declarations.first.else_branch.is_a?(AssignNode),
       "';' ausente antes de 'else' não separa o 'else' do 'if'")

p3d = parse_code("while (i < 3) {\n  i++\n}\nint fim = 1;")
assert(p3d.errors.size == 1 && p3d.parse.declarations.size == 2, "';' ausente dentro do while não afeta o código após o bloco")

# [4] Casos de borda
puts "\n#{YELLOW}[4] Casos de Borda#{RESET}"
p4 = parse_code('int c = 1 2;')
assert(p4.errors.size == 1 && positions(p4) == [[1, 11]],
       "Token estranho na mesma linha ('1 2') gera 1 erro apontando o '2' (obtido: #{positions(p4)})")

p4b = parse_code('x = (a + b;')
assert(p4b.errors.size == 1 && p4b.errors.first.message.include?("Esperado ')'"),
       "Parêntese ausente antes do ';' gera só o erro do ')'")

p4c = parse_code("x = 1\n\n\ny = 2;")
assert(positions(p4c) == [[1, 6]], "Linhas em branco não deslocam o erro para baixo (obtido: #{positions(p4c)})")

# [5] Integração com samples/err_semicolon.c e CLI
puts "\n#{YELLOW}[5] Integração com samples/err_semicolon.c e Saída da CLI#{RESET}"
sample = File.expand_path('../samples/err_semicolon.c', __dir__)
p5 = parse_code(File.read(sample))

assert(positions(p5) == [[2, 11], [5, 10], [11, 12], [13, 13]],
       "4 erros nas linhas 2, 5, 11 e 13 (obtido: #{positions(p5)})")
assert(p5.parse.declarations.size == 5 && p5.parse.declarations.last.body.statements.size == 3,
       'Todos os comandos e o corpo de main continuam na AST')

code5, out5, = run_cli(sample)
assert(code5 == 1, "Exit code 1 quando falta ';'")
assert(out5.include?('✖ [ERRO SINTÁTICO] Falha gramatical na linha 2:'), 'Cabeçalho do diagnóstico cita a linha 2')
assert(out5.include?("     2 | int a = 10\n       |           ^ Esperado ';' após a declaração de 'a'"),
       "Cursor '^' aparece logo após o '10', na própria linha 2")
assert(out5.include?("^ Esperado ';' após 'i++'") && out5.include?("^ Esperado ';' após o 'return'"),
       "Erros dentro de main (i++ e return) também são exibidos")
assert(out5.include?('⚠ Análise semântica não executada: corrija os erros sintáticos acima.'),
       'Semântica não roda e avisa o motivo')

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DE PONTO E VÍRGULA FORAM APROVADOS!            #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
