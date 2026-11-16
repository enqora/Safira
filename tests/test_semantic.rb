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
puts "#{BLUE}  SAFIRA — Testes Unitários da Semântica (src/semantic.rb)      #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Fluxo válido e enriquecimento da tabela de símbolos
puts "#{YELLOW}[1] Fluxo Válido e Tabela de Símbolos#{RESET}"
s1 = analyze("int a = 1;\nfloat b = a + 2.5;\ndouble c = b * 2;\nchar ch = 'x';\na = a + 1;")
assert(s1.valid?, "Programa válido não gera erros (obtido: #{s1.errors.map(&:to_s)})")
assert(s1.symbol_table.map(&:type) == %w[int float double char], 'Tipos declarados preenchidos na tabela de símbolos')
assert(s1.symbol_table.map(&:line) == [1, 2, 3, 4], 'Linha de declaração registrada na tabela')
assert(s1.errors.equal?(s1.errors), 'analyze é idempotente (mesma lista de erros)')

# [2] Incompatibilidade de tipos (Opção 1)
puts "\n#{YELLOW}[2] Incompatibilidade de Tipos (Opção 1)#{RESET}"
s2 = analyze(%(int resultado = "texto";))
err2 = s2.errors.first
assert(s2.errors.size == 1 && err2.kind == :type_mismatch, 'int = "texto" gera 1 erro :type_mismatch')
assert(err2.message == "Não é possível atribuir String a 'resultado' (int).", "Mensagem no formato do especificação (obtido: #{err2.message})")
assert(err2.line == 1 && err2.column == 17 && err2.length == 7, "Apontamento sobre o literal: col 17, 7 colunas (obtido: #{err2.column}/#{err2.length})")

s2b = analyze(%(char c = "abc";\nint a = 1.5;\nint x;\nx = "a";))
assert(kinds(s2b) == %i[type_mismatch type_mismatch type_mismatch], "char=string, int=float e atribuição com string geram 3 erros (obtido: #{kinds(s2b)})")
assert(s2b.errors[1].message.include?('perda de precisão'), 'float -> int avisa perda de precisão')
assert(s2b.errors[2].line == 4 && s2b.errors[2].message.include?("'x' (int)"), 'Erro em atribuição aponta a linha 4 e o alvo x')

s2c = analyze("int a = 1;\nint b = a + 2.5;")
assert(s2c.errors.size == 1 && s2c.errors.first.length == 7, 'Expressão composta: ^^^ cobre "a + 2.5" inteira (7 colunas)')

# [3] Variável não declarada (Opção 2)
puts "\n#{YELLOW}[3] Variável Não Declarada (Opção 2)#{RESET}"
s3 = analyze("y = x + 1;")
assert(kinds(s3) == %i[undeclared_variable undeclared_variable], 'Alvo e operando não declarados geram 2 erros')
assert(s3.errors.map(&:column) == [1, 5], "Colunas apontam y e x (obtido: #{s3.errors.map(&:column)})")
assert(s3.errors.first.message == "Variável 'y' utilizada sem declaração prévia.", 'Mensagem no formato do especificação')

s3b = analyze("int a = b;\nint x = x;")
assert(kinds(s3b) == %i[undeclared_variable undeclared_variable], "Uso em declaração (inclusive 'int x = x;') é não declarado")

s3c = analyze("x = 1;\nint x;")
assert(kinds(s3c) == %i[undeclared_variable], 'Uso antes da declaração é erro (ordem do código)')
assert(s3c.symbol_table.first.line == 2, 'Tabela guarda a linha da declaração, não do primeiro uso')

# [4] Promoção numérica e operadores
puts "\n#{YELLOW}[4] Promoção Numérica e Operadores#{RESET}"
s4 = analyze("int i = 3;\nfloat f = 5;\ndouble d = 1.5;\nfloat t = i + f;\nint q = 7 / 2;\nint m = 7 % 2;\nd = f * i;")
assert(s4.valid?, "Promoções int->float->double e int/int são válidas (obtido: #{s4.errors.map(&:to_s)})")

s4b = analyze("float f = 1.5;\nint n = f * 2;")
assert(kinds(s4b) == %i[type_mismatch], 'float * int resulta em float: não cabe em int')

s4c = analyze("float a = 5.5 % 2;")
assert(kinds(s4c) == %i[invalid_operation], "'%' com float gera :invalid_operation")

s4d = analyze(%(int z = 'a' + 1;\nint w = "s" * 2;))
assert(kinds(s4d) == %i[invalid_operation invalid_operation], 'Aritmética com char/string gera :invalid_operation (sem erro em cascata)')

# [5] Redeclaração
puts "\n#{YELLOW}[5] Redeclaração#{RESET}"
s5 = analyze("int a = 1;\nfloat a = 2.0;\na = 3;")
assert(kinds(s5) == %i[redeclaration], 'Segunda declaração gera :redeclaration')
assert(s5.errors.first.message.include?('linha 1'), 'Mensagem cita a linha da primeira declaração')
assert(s5.symbol_table.first.type == 'int', 'Tipo original é mantido na tabela')

# [6] Resiliência
puts "\n#{YELLOW}[6] Múltiplos Erros e Resiliência#{RESET}"
s6 = analyze(%(int a = "x";\nb = 1;\nfloat f = c;\nint a;))
assert(s6.errors.size == 4, "4 inconsistências acumuladas numa execução (obtido: #{s6.errors.size})")
assert(SemanticAnalyzer.new(nil).valid?, 'AST nil não quebra')
assert(SemanticAnalyzer.new(ProgramNode.new(declarations: [:lixo, nil, 42])).valid?, 'Nós desconhecidos são ignorados sem exceção')
assert(analyze('').valid?, 'Arquivo vazio é válido')

# [7] Integração com samples/
puts "\n#{YELLOW}[7] Integração com Arquivos de Exemplo (samples/*.c)#{RESET}"
sample = ->(name) { analyze(File.read(File.expand_path("../samples/#{name}", __dir__))) }

valid = sample.call('valid.c')
assert(valid.valid?, "samples/valid.c é semanticamente válido (obtido: #{valid.errors.map(&:to_s)})")
assert(valid.symbol_table.map(&:type) == %w[int int int float char], 'valid.c: tabela com todos os tipos preenchidos')

err_type = sample.call('err_type.c')
assert(kinds(err_type) == %i[type_mismatch type_mismatch] && err_type.errors.map(&:line) == [3, 4],
       "err_type.c: 2 erros de tipo nas linhas 3 e 4 (obtido: #{err_type.errors.map { |e| [e.kind, e.line] }})")

err_scope = sample.call('err_scope.c')
assert(kinds(err_scope) == %i[undeclared_variable undeclared_variable] && err_scope.errors.map(&:line) == [5, 6],
       "err_scope.c: 2 variáveis não declaradas nas linhas 5 e 6 (obtido: #{err_scope.errors.map { |e| [e.kind, e.line] }})")

# [8] Restrições do Tipo void e Atribuições Compostas
puts "\n#{YELLOW}[8] Restrições de 'void' e Atribuições Compostas#{RESET}"
s8a = analyze('void x;')
assert(!s8a.valid? && kinds(s8a) == [:invalid_type], "void x; é rejeitado com :invalid_type (obtido: #{kinds(s8a)})")
assert(s8a.errors.first.message == "Variável 'x' não pode ser do tipo 'void'.",
       "Mensagem de erro para variável void (obtido: #{s8a.errors.first.message})")

s8b = analyze('void a = 1;')
assert(kinds(s8b) == [:invalid_type], "void a = 1; é rejeitado com :invalid_type (obtido: #{kinds(s8b)})")

s8c = analyze('int f(void a) { return 0; }')
assert(kinds(s8c) == [:invalid_type], "int f(void a) é rejeitado com :invalid_type (obtido: #{kinds(s8c)})")
assert(s8c.errors.first.message == "Parâmetro 'a' não pode ser do tipo 'void'.",
       "Mensagem de erro para parâmetro void (obtido: #{s8c.errors.first.message})")

s8d = analyze("void f(void) { return; }\nvoid g() { }")
assert(s8d.valid?, "void como retorno e (void) como lista vazia de parâmetros são aceitos (obtido: #{s8d.errors.map(&:to_s)})")

s8e = analyze("int i = 10;\ni += 2;\ni -= 1;\ni *= 3;\ni /= 2;\ni %= 4;")
assert(s8e.valid?, "Operadores compostos com int são semanticamente válidos (obtido: #{s8e.errors.map(&:to_s)})")

s8f = analyze("float f = 2.5;\nf %= 2;")
assert(kinds(s8f) == [:invalid_operation], "f %= 2 com float gera :invalid_operation (obtido: #{kinds(s8f)})")

op_sample = sample.call('operadores.c')
assert(op_sample.valid?, "samples/operadores.c é semanticamente válido (obtido: #{op_sample.errors.map(&:to_s)})")

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DA SEMÂNTICA FORAM APROVADOS COM SUCESSO!     #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
