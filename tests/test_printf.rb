# frozen_string_literal: true

require 'stringio'
require 'tempfile'
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

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes do Comando printf                             #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Lexer: token :KW_PRINTF e proteção da Tabela de Símbolos
puts "#{YELLOW}[1] Lexer: Token :KW_PRINTF e Tabela de Símbolos#{RESET}"
lexer1 = Lexer.new('int printf_count = 1; printf("x = %d\n", printf_count);')
tokens1 = lexer1.tokens

assert(lexer1.valid?, 'Lexer valida comando printf sem erros')
assert(tokens1.any? { |t| t.type == :KW_PRINTF && t.lexeme == 'printf' }, "'printf' gera token :KW_PRINTF")
assert(tokens1.any? { |t| t.type == :IDENTIFICADOR && t.lexeme == 'printf_count' },
       "Identificador 'printf_count' continua sendo :IDENTIFICADOR")
assert(lexer1.symbols.map(&:name) == ['printf_count'],
       "Palavra-chave 'printf' não entra na tabela de símbolos")

# [2] Parser: casos válidos e nós PrintfNode
puts "\n#{YELLOW}[2] Parser: Formatos Válidos de printf#{RESET}"
p2 = parse_code(<<~C)
  printf("Ola mundo\\n");
  printf("Soma: %d + %d = %d\\n", a, b, a + b);
  if (a > 0) printf("positivo\\n"); else printf("nao positivo\\n");
C
decls2 = p2.parse.declarations

assert(p2.valid?, "Comandos printf válidos passam sem erro sintático (obtido: #{p2.errors.map(&:to_s)})")
assert(decls2[0].is_a?(PrintfNode) && decls2[0].arguments.size == 1, 'printf com 1 argumento gera PrintfNode')
assert(decls2[1].is_a?(PrintfNode) && decls2[1].arguments.size == 4 && decls2[1].arguments.last.is_a?(BinaryOpNode),
       'printf com múltiplos argumentos e expressão gera PrintfNode completo')
assert(decls2[2].is_a?(IfNode) && decls2[2].then_branch.is_a?(PrintfNode) && decls2[2].else_branch.is_a?(PrintfNode),
       'printf é aceito como corpo único de if e else sem chaves')

# [3] Parser: erros sintáticos e recuperação em modo pânico
puts "\n#{YELLOW}[3] Parser: Erros Sintáticos e Recuperação#{RESET}"
p3_semi = parse_code("printf(\"oi\")\nint x = 1;")
assert(p3_semi.errors.size == 1 && p3_semi.errors.first.line == 1 &&
       p3_semi.errors.first.message.include?("Esperado ';' após o 'printf'"),
       "';' ausente após printf aponta erro na linha 1")
assert(p3_semi.parse.declarations.size == 2, 'Comando após printf sem ; é preservado na AST')

p3_paren = parse_code("printf(\"oi\";\nint x = 1;")
assert(p3_paren.errors.size == 1 && p3_paren.errors.first.message.include?("Esperado ')'"),
       "')' ausente antes de ';' gera 1 erro sem duplicar erro de ';'")
assert(p3_paren.parse.declarations.size == 2, 'Recupera após ) ausente e preserva próximo comando')

p3_empty = parse_code("printf();\nint x = 1;")
assert(p3_empty.errors.size == 1 && p3_empty.errors.first.message.include?('ao menos um argumento'),
       'printf() vazio gera erro sintático específico')
assert(p3_empty.parse.declarations.last.is_a?(VarDeclNode), 'Recupera de printf() vazio e continua parsing')

p3_comma = parse_code("printf(\"oi\", );\nint x = 1;")
assert(p3_comma.errors.size == 1 && p3_comma.parse.declarations.last.is_a?(VarDeclNode),
       'Vírgula sem argumento após ela gera erro e recupera no comando seguinte')

p3_open = parse_code("printf \"oi\";\nint x = 1;")
assert(p3_open.errors.size == 1 && p3_open.errors.first.message.include?("Esperado '('"),
       'printf sem parêntese de abertura gera erro claro e recupera')

# [4] Semântica: casos válidos com especificadores de formato
puts "\n#{YELLOW}[4] Semântica: Especificadores e Tipos Compatíveis#{RESET}"
s4 = analyze(<<~C)
  int i = 10;
  float f = 2.5;
  double d = 3.14;
  char c = 'S';
  printf("Simples 100%%\\n");
  printf("i=%d %i %u %x %o\\n", i, -i, 5, 255, 8);
  printf("f=%.2f d=%lf e=%e\\n", f, d, f);
  printf("c=%c s=%s\\n", c, "Safira");
  printf("largura=%*d\\n", 4, i + 1);
C
assert(s4.valid?, "Todos os especificadores válidos passam na semântica (obtido: #{s4.errors.map(&:to_s)})")

# [5] Semântica: erros de formato, tipo, aridade e variável não declarada
puts "\n#{YELLOW}[5] Semântica: Erros de Formato, Tipo, Aridade e Escopo#{RESET}"
s5_fmt = analyze('printf(123);')
assert(kinds(s5_fmt) == %i[type_mismatch] &&
       s5_fmt.errors.first.message == "O primeiro argumento de 'printf' deve ser String, mas recebeu int.",
       'Primeiro argumento não-String gera :type_mismatch')

s5_types = analyze(<<~C)
  int i = 1;
  float f = 2.5;
  char c = 'A';
  printf("%d", f);
  printf("%f", i);
  printf("%c", "A");
  printf("%s", i);
  printf("%d", "texto");
C
assert(kinds(s5_types) == %i[type_mismatch type_mismatch type_mismatch type_mismatch type_mismatch],
       "Incompatibilidades entre especificadores e argumentos geram :type_mismatch (obtido: #{kinds(s5_types)})")

s5_arity = analyze(<<~C)
  int a = 1;
  printf("%d %d", a);
  printf("sem placeholder", a);
C
assert(kinds(s5_arity) == %i[invalid_operation invalid_operation],
       'Falta e excesso de argumentos geram :invalid_operation')
assert(s5_arity.errors[0].message.include?('insuficiente') && s5_arity.errors[1].message.include?('excessiva'),
       'Mensagens distinguem falta e excesso de argumentos')

s5_undecl = analyze('printf("val = %d", nao_declarada);')
assert(kinds(s5_undecl) == %i[undeclared_variable],
       'Variável não declarada dentro de printf gera apenas :undeclared_variable, sem cascata')

s5_fn = analyze("int main() { printf(\"%d\", main); return 0; }")
assert(kinds(s5_fn) == %i[invalid_operation],
       'Nome de função passado ao printf gera :invalid_operation, sem cascata')

# [6] Integração com samples/printf.c e renderização da CLI
puts "\n#{YELLOW}[6] Integração com samples/printf.c e Renderização da CLI#{RESET}"
sample_path = File.expand_path('../samples/printf.c', __dir__)
code6, out6, err6 = run_cli(sample_path)

assert(code6.zero? && err6.empty?, 'samples/printf.c executa com exit code 0 e stderr vazio')
assert(out6.include?('TIPO: KW_PRINTF'), 'Lista de tokens exibe TIPO: KW_PRINTF')
assert(!out6.include?('| printf'), 'Tabela de símbolos não inclui printf como variável')
assert(out6.include?('Saida (printf)'), 'AST exibe nó Saida (printf)')
assert(out6.include?('STR ("Sistema Safira\n")'), 'AST exibe literal string de printf')
assert(out6.include?('✔ Nenhuma inconsistência semântica encontrada.'), 'samples/printf.c é semanticamente válido')

Tempfile.create(['printf_err', '.c']) do |tmp|
  tmp.write("int main() {\n    int x = 10;\n    printf(\"x = %f\", x);\n    return 0;\n}\n")
  tmp.flush
  code_err, out_err, = run_cli(tmp.path, '--semantic')
  assert(code_err == 1 && out_err.include?('✖ [ERRO SEMÂNTICO] Incompatibilidade de tipos na linha 3:') &&
         out_err.include?("^ Especificador '%f' de 'printf' espera float ou double, mas recebeu int."),
         'CLI exibe erro semântico de printf com cursor alinhado ao argumento')
end

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DO COMANDO PRINTF FORAM APROVADOS!            #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
