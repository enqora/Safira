# frozen_string_literal: true

require_relative '../src/lexer'
require_relative '../src/parser'

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
  lexer = Lexer.new(source)
  Parser.new(lexer.tokens)
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes Unitários do Parser (src/parser.rb)           #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Declarações simples, inicializadas e múltiplas
puts "#{YELLOW}[1] Declarações de Variáveis (Simples, Inicializada e Múltipla)#{RESET}"
p1 = parse_code("int x;\nfloat y = 2.5;\nint a, b = 10;")
ast1 = p1.parse

assert(p1.valid?, 'Nenhum erro sintático nas declarações válidas')
assert(ast1.is_a?(ProgramNode), 'parse devolve um ProgramNode')
assert(ast1.declarations.size == 4, "Total de 4 VarDeclNode gerados (obtido: #{ast1.declarations.size})")

decl_x, decl_y, decl_a, decl_b = ast1.declarations
assert(decl_x.is_a?(VarDeclNode) && decl_x.name_token.lexeme == 'x' && decl_x.expression.nil?,
       "'int x;' gera VarDeclNode com expression nil")
assert(decl_y.is_a?(VarDeclNode) && decl_y.type_token.lexeme == 'float' && decl_y.expression.is_a?(NumberNode),
       "'float y = 2.5;' gera VarDeclNode com NumberNode")
assert(decl_a.name_token.lexeme == 'a' && decl_a.expression.nil? &&
       decl_b.name_token.lexeme == 'b' && decl_b.expression.is_a?(NumberNode),
       "'int a, b = 10;' expande em dois VarDeclNode preservando o tipo 'int'")

# [2] Atribuições e Literais (NumberNode, StringNode, CharNode, IdentifierNode)
puts "\n#{YELLOW}[2] Atribuições e Nós de Literais#{RESET}"
p2 = parse_code(%(char c = 'M';\ntexto = "safira";\nx = c;))
ast2 = p2.parse

assert(p2.valid?, 'Nenhum erro sintático nas atribuições com literais')
decl_c, assign_str, assign_id = ast2.declarations
assert(decl_c.expression.is_a?(CharNode) && decl_c.expression.token.lexeme == "'M'",
       "Literal 'M' gera CharNode")
assert(assign_str.is_a?(AssignNode) && assign_str.target.lexeme == 'texto' && assign_str.expression.is_a?(StringNode),
       'Atribuição de string gera AssignNode com StringNode')
assert(assign_id.is_a?(AssignNode) && assign_id.expression.is_a?(IdentifierNode),
       'Atribuição com variável à direita gera IdentifierNode')

# [3] Precedência de Operadores (* / % antes de + -)
puts "\n#{YELLOW}[3] Precedência Matemática (* / % antes de + -)#{RESET}"
p3 = parse_code('x = a + b * c;')
expr3 = p3.parse.declarations.first.expression

assert(p3.valid?, "Expressão 'a + b * c' é válida")
assert(expr3.is_a?(BinaryOpNode) && expr3.operator_token.lexeme == '+',
       "Raiz de 'a + b * c' é o operador '+'")
assert(expr3.left.is_a?(IdentifierNode) && expr3.left.token.lexeme == 'a',
       "Lado esquerdo de '+' é 'a'")
assert(expr3.right.is_a?(BinaryOpNode) && expr3.right.operator_token.lexeme == '*',
       "Lado direito de '+' é a subárvore 'b * c'")

# [4] Associatividade à Esquerda e Parênteses
puts "\n#{YELLOW}[4] Associatividade à Esquerda e Agrupamento com Parênteses#{RESET}"
p4_assoc = parse_code('x = a - b - c;')
expr_assoc = p4_assoc.parse.declarations.first.expression

assert(expr_assoc.operator_token.lexeme == '-' &&
       expr_assoc.left.is_a?(BinaryOpNode) &&
       expr_assoc.left.left.token.lexeme == 'a' &&
       expr_assoc.left.right.token.lexeme == 'b' &&
       expr_assoc.right.token.lexeme == 'c',
       "'a - b - c' agrupa à esquerda como '(a - b) - c'")

p4_paren = parse_code('x = (a + b) * c % 2;')
expr_paren = p4_paren.parse.declarations.first.expression

assert(p4_paren.valid?, "Expressão '(a + b) * c % 2' é válida")
assert(expr_paren.operator_token.lexeme == '%' &&
       expr_paren.left.operator_token.lexeme == '*' &&
       expr_paren.left.left.operator_token.lexeme == '+',
       "Parênteses sobrepõem a precedência padrão: '((a + b) * c) % 2'")

# [5] Detecção de Erros Sintáticos e Posição Exata
puts "\n#{YELLOW}[5] Detecção de Erros Sintáticos (Falta de ';', Expressão Vazia, Parêntese)#{RESET}"
p5_semi = parse_code('int x = 5')
p5_semi.parse
assert(!p5_semi.valid? && p5_semi.errors.size == 1, "Falta de ';' gera 1 ParseError")
assert(p5_semi.errors.first.message.include?("Esperado ';'"), "Mensagem indica falta de ';'")

p5_empty = parse_code('x = ;')
p5_empty.parse
assert(!p5_empty.valid? && p5_empty.errors.first.column == 5,
       "Expressão vazia 'x = ;' aponta erro na coluna 5 (obtido: #{p5_empty.errors.first.column})")

p5_paren = parse_code('x = (a + b;')
p5_paren.parse
assert(!p5_paren.valid? && p5_paren.errors.first.message.include?("Esperado ')'"),
       "Parêntese não fechado reporta falta de ')'")

# [6] Recuperação em Modo Pânico (Múltiplos Erros sem Traceback)
puts "\n#{YELLOW}[6] Recuperação em Modo Pânico e Resiliência#{RESET}"
broken_code = <<~C
  int a = ;
  x = 10 + * 20;
  int valido = 42;
  = ; ) (
C

p6 = parse_code(broken_code)
ast6 = p6.parse

assert(!p6.valid? && p6.errors.size >= 3,
       "Múltiplos erros acumulados em uma única execução (obtido: #{p6.errors.size})")
assert(ast6.declarations.any? { |d| d.is_a?(VarDeclNode) && d.name_token.lexeme == 'valido' },
       "Comando válido entre linhas com erro ('int valido = 42;') ainda é incluído na AST")

p6_empty = parse_code('')
assert(p6_empty.valid? && p6_empty.parse.declarations.empty?,
       'Arquivo vazio devolve ProgramNode vazio e válido')

# [7] Validação dos Arquivos em samples/
puts "\n#{YELLOW}[7] Integração com Arquivos de Exemplo (samples/*.c)#{RESET}"
%w[valid.c err_type.c err_scope.c].each do |sample|
  path = File.expand_path("../samples/#{sample}", __dir__)
  code = File.read(path)
  lexer = Lexer.new(code)
  parser = Parser.new(lexer.tokens)
  parser.parse
  assert(lexer.valid? && parser.valid?, "samples/#{sample} passa nas análises léxica e sintática")
end

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES UNITÁRIOS DO PARSER FORAM APROVADOS COM SUCESSO!#{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
