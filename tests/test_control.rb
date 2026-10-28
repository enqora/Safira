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

def analyze(source)
  lexer = Lexer.new(source)
  semantic = SemanticAnalyzer.new(Parser.new(lexer.tokens).parse, lexer.symbols)
  semantic.analyze
  semantic
end

def kinds(semantic) = semantic.errors.map(&:kind)

def run_cli(*args)
  out = StringIO.new
  err = StringIO.new
  code = SafiraCLI::Runner.run(args + ['--no-color'], out: out, err: err)
  [code, out.string, err.string]
end

def sample_path(name) = File.expand_path("../samples/#{name}", __dir__)

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes das Estruturas de Controle (if/else/while/for) #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Palavras-chave no Lexer
puts "#{YELLOW}[1] Palavras-chave de Controle no Lexer#{RESET}"
lexer1 = Lexer.new('for (i = 0; i < 3; i++) { if (i) { } else { } while (i) { } }')
types1 = lexer1.tokens.map(&:type)

assert(lexer1.valid?, 'Nenhum erro léxico com if/else/while/for')
assert(%i[KW_FOR KW_IF KW_ELSE KW_WHILE].all? { |k| types1.include?(k) }, "'for', 'if', 'else' e 'while' geram :KW_*")
assert(lexer1.symbols.map(&:name) == %w[i], "Palavras-chave NÃO entram na tabela de símbolos (obtido: #{lexer1.symbols.map(&:name)})")

# [2] if / else / else if
puts "\n#{YELLOW}[2] Parser: if, else e else if#{RESET}"
p2 = parse_code("if (x > 0) { y = 1; } else if (x < 0) { y = 2; } else y = 3;")
if2 = p2.parse.declarations.first

assert(p2.valid?, "Cadeia if / else if / else é válida (obtido: #{p2.errors.map(&:to_s)})")
assert(if2.is_a?(IfNode) && if2.condition.operator_token.lexeme == '>', "Condição do 'if' vira Expressao (>)")
assert(if2.then_branch.is_a?(BlockNode) && if2.then_branch.statements.first.is_a?(AssignNode), "Ramo 'então' com chaves gera BlockNode")
assert(if2.else_branch.is_a?(IfNode), "'else if' gera um IfNode aninhado no ramo 'senão'")
assert(if2.else_branch.else_branch.is_a?(AssignNode), "'else' sem chaves aceita um único comando")

p2b = parse_code('if (a) if (b) x = 1; else x = 2;')
outer = p2b.parse.declarations.first
assert(outer.else_branch.nil? && outer.then_branch.else_branch.is_a?(AssignNode),
       "'else' pendente pertence ao 'if' mais próximo, como em C")

# [3] while e blocos
puts "\n#{YELLOW}[3] Parser: while e Blocos Aninhados#{RESET}"
p3 = parse_code("while (i < 10) {\n  i = i + 1;\n  { int t = i; }\n}")
while3 = p3.parse.declarations.first

assert(p3.valid?, "while com bloco aninhado é válido (obtido: #{p3.errors.map(&:to_s)})")
assert(while3.is_a?(WhileNode) && while3.body.statements.size == 2, 'Corpo do while tem 2 comandos')
assert(while3.body.statements.last.is_a?(BlockNode), 'Bloco solto dentro do while gera BlockNode')

# [4] for
puts "\n#{YELLOW}[4] Parser: for (Inicialização, Condição e Passo)#{RESET}"
p4 = parse_code('for (int i = 0; i < 10; i++) soma = soma + i;')
for4 = p4.parse.declarations.first

assert(p4.valid?, "for com declaração e i++ é válido (obtido: #{p4.errors.map(&:to_s)})")
assert(for4.is_a?(ForNode) && for4.init.first.is_a?(VarDeclNode), "Inicialização 'int i = 0' gera VarDeclNode")
assert(for4.condition.operator_token.lexeme == '<', "Condição 'i < 10' é preservada")
assert(for4.update.is_a?(IncDecNode) && for4.update.operator_token.lexeme == '++', "Passo 'i++' gera IncDecNode")

p4b = parse_code('for (;;) { x = 1; }')
for4b = p4b.parse.declarations.first
assert(p4b.valid? && for4b.init.empty? && for4b.condition.nil? && for4b.update.nil?,
       "'for (;;)' aceita as três partes vazias")

p4c = parse_code('for (i = 10; i > 0; i = i - 1) { }')
assert(p4c.valid? && p4c.parse.declarations.first.update.is_a?(AssignNode), "Passo com atribuição 'i = i - 1' é aceito")

# [5] Funções e return
puts "\n#{YELLOW}[5] Parser: Funções, Parâmetros e return#{RESET}"
p5 = parse_code("int soma(int a, float b) {\n  return a + b;\n}\nvoid nada(void) { return; }")
soma5, nada5 = p5.parse.declarations

assert(p5.valid?, "Funções com parâmetros e (void) são válidas (obtido: #{p5.errors.map(&:to_s)})")
assert(soma5.is_a?(FunctionDefNode) && soma5.params.map { |p| p.name_token.lexeme } == %w[a b], "Parâmetros 'a' e 'b' reconhecidos")
assert(soma5.body.statements.first.is_a?(ReturnNode), "Corpo da função contém o ReturnNode")
assert(nada5.params.empty? && nada5.body.statements.first.expression.nil?, "'(void)' sem parâmetros e 'return;' sem valor")

# [6] Precedência de operadores relacionais e lógicos
puts "\n#{YELLOW}[6] Precedência: || → && → == → < → + → * → unário#{RESET}"
expr6 = parse_code('x = a + 1 < b && c == d || !e;').parse.declarations.first.expression

assert(expr6.operator_token.lexeme == '||', "Raiz de 'a + 1 < b && c == d || !e' é '||'")
assert(expr6.left.operator_token.lexeme == '&&', "Lado esquerdo de '||' é a subárvore '&&'")
assert(expr6.left.left.operator_token.lexeme == '<' && expr6.left.left.left.operator_token.lexeme == '+',
       "'+' é avaliado antes de '<'")
assert(expr6.left.right.operator_token.lexeme == '==', "'==' fica abaixo de '&&'")
assert(expr6.right.is_a?(UnaryOpNode) && expr6.right.operator_token.lexeme == '!', "'!e' gera UnaryOpNode")

expr6b = parse_code('x = -a * 2;').parse.declarations.first.expression
assert(expr6b.operator_token.lexeme == '*' && expr6b.left.is_a?(UnaryOpNode), "Menos unário tem precedência sobre '*'")

# [7] Erros sintáticos nas estruturas de controle
puts "\n#{YELLOW}[7] Erros Sintáticos em if/else/while/for#{RESET}"
p7a = parse_code("if x > 0 { y = 1; } else { y = 2; }")
assert(p7a.errors.size == 1 && p7a.errors.first.message.include?('entre parênteses'),
       "'if' sem parênteses gera 1 erro (obtido: #{p7a.errors.map(&:message)})")
assert(p7a.parse.declarations.first.else_branch.is_a?(BlockNode), "O 'else' continua ligado ao 'if' após o erro")

p7b = parse_code("while (x > 0 {\n  x = x - 1;\n}")
assert(p7b.errors.size == 1 && p7b.errors.first.message.include?("Esperado ')'"),
       "while sem ')' gera 1 erro (obtido: #{p7b.errors.map(&:message)})")
assert(p7b.errors.first.line == 1 && p7b.errors.first.column == 13, "Erro aponta logo após o '0' (linha 1, col 13)")

p7c = parse_code("for (i = 0 i < 10; i++) {\n  x = 1;\n}\ny = 2;")
assert(p7c.errors.size == 1 && p7c.errors.first.message.include?("inicialização do 'for'"),
       "for sem ';' no cabeçalho gera 1 erro, sem cascata (obtido: #{p7c.errors.map(&:message)})")
assert(p7c.parse.declarations.last.is_a?(AssignNode), "Comando após o 'for' com erro ('y = 2;') continua na AST")

p7d = parse_code("x = 1;\nelse { x = 2; }")
assert(p7d.errors.size == 1 && p7d.errors.first.message.include?("'else' sem um 'if'"), "'else' solto gera erro próprio")

p7e = parse_code("int main() {\n  x = 1;\n")
assert(p7e.errors.size == 1 && p7e.errors.first.message.include?('não foi fechado'), "Bloco sem '}' é detectado")
assert(p7e.errors.first.line == 1 && p7e.errors.first.column == 12, "Erro aponta para o '{' que ficou aberto")
assert(p7e.parse.declarations.first.is_a?(FunctionDefNode), 'Função com bloco aberto ainda aparece na AST')

p7f = parse_code("x = 1;\n}\ny = 2;")
assert(p7f.errors.size == 1 && p7f.errors.first.message.include?("'}' sem um '{'"), "'}' sobrando gera 1 erro")
assert(p7f.parse.declarations.size == 2, "Comandos ao redor do '}' sobrando são preservados")

p7g = parse_code('int main() { int f() { } }')
assert(p7g.errors.any? { |e| e.message.include?('fora de blocos') }, 'Função definida dentro de bloco é rejeitada')

p7h = parse_code("if (a) { x = ; }\ny = 1;")
assert(p7h.errors.size == 1 && p7h.parse.declarations.size == 2,
       "Erro dentro do corpo do 'if' não derruba o 'if' nem o comando seguinte")

# [8] Escopo de blocos
puts "\n#{YELLOW}[8] Semântica: Escopo de Blocos e do for#{RESET}"
s8 = analyze("int x = 1;\nif (x > 0) {\n  int y = 2;\n  x = y;\n}\nx = y;")
assert(kinds(s8) == %i[undeclared_variable] && s8.errors.first.line == 6,
       "Variável do bloco não existe fora dele (obtido: #{s8.errors.map(&:to_s)})")

s8b = analyze("for (int i = 0; i < 3; i++) { }\ni = 5;")
assert(kinds(s8b) == %i[undeclared_variable] && s8b.errors.first.line == 2, "Variável declarada no 'for' só existe no 'for'")

s8c = analyze("int x = 1;\n{\n  float x = 2.5;\n}\nx = 3;")
assert(s8c.valid?, "Sombreamento em bloco interno é permitido (obtido: #{s8c.errors.map(&:to_s)})")
assert(s8c.symbol_table.map { |s| [s.name, s.type] } == [%w[x int], %w[x float]],
       'Tabela de símbolos registra as duas declarações de x')

s8d = analyze("{\n  int a = 1;\n  int a = 2;\n}")
assert(kinds(s8d) == %i[redeclaration], 'Redeclaração no mesmo bloco continua sendo erro')

s8e = analyze("for (int i = 0; i < 2; i++) { }\nfor (int i = 0; i < 2; i++) { }")
assert(s8e.valid?, "Dois 'for' declarando 'i' não conflitam")

# [9] Condições e operadores
puts "\n#{YELLOW}[9] Semântica: Condições e Operadores Relacionais/Lógicos#{RESET}"
s9 = analyze(%(int x = 1;\nif ("sim") { x = 2; }\nwhile (x) { x = 0; }))
assert(kinds(s9) == %i[invalid_condition], "String como condição é inválida; int como condição é válido (obtido: #{kinds(s9)})")
assert(s9.errors.first.column == 5 && s9.errors.first.length == 5, 'Cursor cobre o literal "sim"')

s9b = analyze("char c = 'a';\nint n = 1;\nint r = c == 'b';\nint s = c < n;")
assert(kinds(s9b) == %i[invalid_operation] && s9b.errors.first.line == 4,
       "char == char é válido; char < int é inválido (obtido: #{s9b.errors.map(&:to_s)})")

s9c = analyze(%(int a = 1;\nfloat f = 2.5;\nint b = a < f && f >= 1;\nint c = "x" || a;\nint d = !"y";))
assert(kinds(s9c) == %i[invalid_operation invalid_operation], "Comparação int/float é válida; String com || ou ! não (obtido: #{kinds(s9c)})")

s9d = analyze("char c = 'a';\nc++;\nk--;")
assert(kinds(s9d) == %i[invalid_operation undeclared_variable], "'c++' em char e 'k--' não declarado geram erro (obtido: #{kinds(s9d)})")

# [10] Funções e return
puts "\n#{YELLOW}[10] Semântica: Funções, Parâmetros e return#{RESET}"
s10 = analyze("int dobro(int n) {\n  return n * 2;\n}\nfloat media(int a, int b) {\n  return (a + b) / 2.0;\n}")
assert(s10.valid?, "Parâmetros são visíveis no corpo e retornos compatíveis são aceitos (obtido: #{s10.errors.map(&:to_s)})")
assert(s10.symbol_table.first.type == 'função int(int)', "Tabela mostra a assinatura 'função int(int)' (obtido: #{s10.symbol_table.first.type})")

s10b = analyze(%(int f() {\n  return "texto";\n}\nint g() {\n  float x = 1.5;\n  return x;\n}))
assert(kinds(s10b) == %i[type_mismatch type_mismatch], 'Retorno de String e de float em função int gera erro')
assert(s10b.errors.last.message.include?('perda de precisão'), 'float → int no return avisa perda de precisão')

s10c = analyze("void p() {\n  return 1;\n}\nreturn 0;")
assert(kinds(s10c) == %i[invalid_return invalid_return], "void retornando valor e 'return' fora de função geram erro (obtido: #{kinds(s10c)})")

s10d = analyze("int main() { return 0; }\nint x = main;\nmain = 1;")
assert(kinds(s10d) == %i[invalid_operation invalid_operation], 'Nome de função não pode ser usado como variável')

s10e = analyze("int f(int a) {\n  int a = 2;\n  return a;\n}")
assert(kinds(s10e) == %i[redeclaration], 'Parâmetro e variável do corpo dividem o mesmo escopo (redeclaração)')

# [11] Integração com samples/
puts "\n#{YELLOW}[11] Integração com Arquivos de Exemplo (samples/*.c)#{RESET}"
%w[loops.c conditionals.c].each do |name|
  semantic = analyze(File.read(sample_path(name)))
  assert(semantic.valid?, "samples/#{name} passa nas 3 análises (obtido: #{semantic.errors.map(&:to_s)})")
end

ctrl_parser = parse_code(File.read(sample_path('err_control.c')))
assert(ctrl_parser.errors.map(&:line) == [6, 10, 14, 18],
       "err_control.c: 4 erros sintáticos nas linhas 6, 10, 14 e 18 (obtido: #{ctrl_parser.errors.map(&:line)})")

ctrl_semantic = analyze(File.read(sample_path('err_control_semantic.c')))
assert(kinds(ctrl_semantic) == %i[undeclared_variable undeclared_variable invalid_condition type_mismatch] &&
       ctrl_semantic.errors.map(&:line) == [6, 13, 15, 19],
       "err_control_semantic.c: 4 erros semânticos nas linhas 6, 13, 15 e 19 (obtido: #{ctrl_semantic.errors.map { |e| [e.kind, e.line] }})")

# [12] Renderização na CLI
puts "\n#{YELLOW}[12] Renderização da AST e Diagnósticos na CLI#{RESET}"
code12, out12, = run_cli(sample_path('loops.c'))
assert(code12.zero?, 'loops.c retorna exit code 0')
assert(out12.include?('Funcao (main)') && out12.include?('Repeticao (while)') && out12.include?('Repeticao (for)'),
       'AST exibe Funcao, Repeticao (while) e Repeticao (for)')
assert(out12.include?('├── Inicializacao') && out12.include?('├── Passo') && out12.include?('Retorno (return)'),
       'AST do for exibe Inicializacao e Passo; return vira Retorno')
assert(out12.include?('| main          | função int() |'), 'Tabela de símbolos mostra a função main')

_, out12b, = run_cli(sample_path('conditionals.c'), '--ast')
assert(out12b.include?('Condicional (if)') && out12b.include?('├── Entao') && out12b.include?('└── Senao'),
       'AST do if exibe Condicao, Entao e Senao')
assert(out12b.include?('Unario (!)'), "Operador '!' aparece como Unario (!)")

code12c, out12c, = run_cli(sample_path('err_control_semantic.c'), '--semantic')
assert(code12c == 1 && out12c.include?('✖ [ERRO SEMÂNTICO] Condição inválida na linha 15:'),
       'Diagnóstico de condição inválida com título próprio')
assert(out12c.include?("^^^^^ Não é possível retornar float na função 'main' (int)."),
       'Diagnóstico de retorno incompatível com cursor sob a expressão')

code12d, out12d, = run_cli(sample_path('err_control.c'))
assert(code12d == 1 && out12d.include?("^ A condição do 'if' deve estar entre parênteses"),
       'Erro sintático do if exibido com cursor')
assert(out12d.include?('⚠ Análise semântica não executada'), 'Semântica não roda quando há erro sintático')

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DAS ESTRUTURAS DE CONTROLE FORAM APROVADOS!    #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
