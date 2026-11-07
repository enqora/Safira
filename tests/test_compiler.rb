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
  end
  $falhas += 1 unless condition
end

def run_cli(*args)
  out = StringIO.new
  err = StringIO.new
  code = SafiraCLI::Runner.run(args + ['--no-color'], out: out, err: err)
  [code, out.string, err.string]
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes da CLI e Renderizador (safira.rb)             #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

valid_path     = File.expand_path('../samples/valid.c', __dir__)
err_type_path  = File.expand_path('../samples/err_type.c', __dir__)
err_scope_path = File.expand_path('../samples/err_scope.c', __dir__)

# [1] Execução completa em samples/valid.c
puts "#{YELLOW}[1] Execução Completa (samples/valid.c)#{RESET}"
code1, out1, err1 = run_cli(valid_path)

assert(code1.zero? && err1.empty?, 'Exit code 0 e stderr vazio para valid.c')
assert(out1.include?('[1] ANÁLISE LÉXICA: LISTA DE TOKENS'), 'Exibe seção [1] Lista de Tokens')
assert(out1.include?('[2] TABELA DE SÍMBOLOS'), 'Exibe seção [2] Tabela de Símbolos')
assert(out1.include?('[3] ANÁLISE SINTÁTICA: ÁRVORE SINTÁTICA (AST)'), 'Exibe seção [3] Árvore Sintática (AST)')
assert(out1.include?('[4] ANÁLISE SEMÂNTICA'), 'Exibe seção [4] Análise Semântica')
assert(out1.include?('| total         | float   |'), 'Tabela de símbolos exibe tipos preenchidos pela semântica')
assert(out1.include?(" Programa\n") && out1.include?('├── Tipo (int)'), 'AST usa raiz Programa e rótulo padronizado Tipo')
assert(out1.include?('├── ID (x)') && out1.include?('└── Expressao (+)'), 'AST usa conectores Unicode hierárquicos')
assert(out1.include?('✔ Nenhuma inconsistência semântica encontrada.'), 'Exibe mensagem de sucesso semântico')

# [2] Diagnóstico de incompatibilidade de tipos (samples/err_type.c)
puts "\n#{YELLOW}[2] Diagnósticos de Tipo (samples/err_type.c)#{RESET}"
code2, out2, = run_cli(err_type_path)

assert(code2 == 1, 'Exit code 1 quando há erro semântico de tipo')
assert(out2.include?('✖ [ERRO SEMÂNTICO] Incompatibilidade de tipos na linha 3:'),
       'Exibe cabeçalho de incompatibilidade de tipos na linha 3')
assert(out2.include?('3 | int resultado = "texto";'), 'Exibe a linha 3 do código-fonte')
assert(out2.include?("^^^^^^^ Não é possível atribuir String a 'resultado' (int)."),
       'Exibe cursor ^^^^^^^ alinhado com a mensagem de erro')

# [3] Diagnóstico de variável não declarada (samples/err_scope.c)
puts "\n#{YELLOW}[3] Diagnósticos de Escopo (samples/err_scope.c)#{RESET}"
code3, out3, = run_cli(err_scope_path)

assert(code3 == 1, 'Exit code 1 quando há variável não declarada')
assert(out3.include?('✖ [ERRO SEMÂNTICO] Variável não declarada na linha 5:'),
       'Exibe cabeçalho de variável não declarada na linha 5')
assert(out3.include?("^^^^^ Variável 'total' utilizada sem declaração prévia."),
       "Exibe cursor ^^^^^ sob 'total'")
assert(out3.include?("^^^^^^^^^^^ Variável 'inexistente' utilizada sem declaração prévia."),
       "Exibe cursor ^^^^^^^^^^^ sob 'inexistente'")

# [4] Flags isoladas (--tokens, --symbols, --ast, --semantic)
puts "\n#{YELLOW}[4] Modos de Demonstração por Flags#{RESET}"
_, out_tok, = run_cli(valid_path, '--tokens')
assert(out_tok.include?('[1] ANÁLISE LÉXICA') && !out_tok.include?('[2] TABELA') && !out_tok.include?('[3] ANÁLISE'),
       '--tokens exibe apenas a seção [1]')

_, out_sym, = run_cli(valid_path, '--symbols')
assert(out_sym.include?('[2] TABELA DE SÍMBOLOS') && out_sym.include?('| float   |') && !out_sym.include?('[1]'),
       '--symbols exibe apenas a seção [2] já enriquecida com os tipos')

_, out_ast, = run_cli(valid_path, '--ast')
assert(out_ast.include?('[3] ANÁLISE SINTÁTICA') && !out_ast.include?('[1]') && !out_ast.include?('[4]'),
       '--ast exibe apenas a seção [3]')
assert(!out_ast.include?('OP_ATRIB (=)') && !out_ast.include?('TIPO_DADO'),
       'AST não expõe tokens OP_ATRIB ou TIPO_DADO brutos')

_, out_sem, = run_cli(valid_path, '--semantic')
assert(out_sem.include?('[4] ANÁLISE SEMÂNTICA') && !out_sem.include?('[1]') && !out_sem.include?('[3]'),
       '--semantic exibe apenas a seção [4]')

# [5] Resiliência e Tratamento de Erros de CLI (Sem Tracebacks)
puts "\n#{YELLOW}[5] Resiliência de CLI e Erros Léxicos/Sintáticos#{RESET}"
code_no_args, _, err_no_args = run_cli
assert(code_no_args == 1 && err_no_args.include?('Nenhum arquivo'), 'Sem argumentos retorna código 1 com mensagem amigável')

code_missing, _, err_missing = run_cli('nao_existe.c')
assert(code_missing == 1 && err_missing.include?('Arquivo não encontrado'), 'Arquivo inexistente não lança exceção')

code_dir, _, err_dir = run_cli(__dir__)
assert(code_dir == 1 && err_dir.include?('diretório'), 'Diretório informado como arquivo é barrado com mensagem clara')

code_help, out_help, = run_cli('--help')
assert(code_help.zero? && out_help.include?('Uso: ruby safira.rb'), '--help retorna código 0 e instruções de uso')

Tempfile.create(['broken', '.c']) do |tmp|
  tmp.write("int @x = ;\n")
  tmp.flush
  code_brk, out_brk, = run_cli(tmp.path)
  assert(code_brk == 1 && out_brk.include?('[ERRO LÉXICO]') && out_brk.include?('[ERRO SINTÁTICO]'),
         'Erros léxicos e sintáticos também são formatados com diagnóstico visual sem quebrar')
end

# [6] Supressão de cascata semântica em caso de erro sintático
puts "\n#{YELLOW}[6] Supressão de Cascata Semântica em Erros Sintáticos#{RESET}"
Tempfile.create(['cascade', '.c']) do |tmp|
  tmp.write("int a = ;\na = 1;\nint b = a + 2;\n")
  tmp.flush
  code_casc, out_casc, = run_cli(tmp.path)
  assert(code_casc == 1, 'Exit code 1 quando há erro sintático com cascata evitada')
  assert(out_casc.include?('[ERRO SINTÁTICO]'), 'Identifica o erro sintático na linha 1')
  assert(out_casc.include?('⚠ Análise semântica não executada: corrija os erros sintáticos acima.'),
         'Exibe aviso claro de que a semântica não foi executada')
  assert(!out_casc.include?('[ERRO SEMÂNTICO]'),
         'Não emite falsos positivos de "variável não declarada" para linhas 2 e 3')
end

# [7] Diretivas não impedem a análise semântica
puts "\n#{YELLOW}[7] Diretivas de Pré-processador#{RESET}"
directives_path = File.expand_path('../samples/diretivas.c', __dir__)
code_directives, out_directives, err_directives = run_cli(directives_path)
assert(code_directives.zero? && err_directives.empty?, 'Sample com diretivas passa pelo compilador')
assert(out_directives.include?('Nenhuma inconsistência semântica encontrada.'),
       'Análise semântica é executada após ignorar diretivas')
Tempfile.create(['directives', '.c']) do |tmp|
  tmp.write("#include <stdio.h>\nint main() {\n    int valor = ausente;\n    return 0;\n}\n")
  tmp.flush
  code_error, out_error, = run_cli(tmp.path)
  assert(code_error == 1 && out_error.include?('[ERRO SEMÂNTICO]') && out_error.include?('ausente'),
         'Erro semântico real após diretiva continua sendo detectado')
  assert(!out_error.include?('[ERRO LÉXICO]') && !out_error.include?('[ERRO SINTÁTICO]'),
         'Diretiva não produz erros nas etapas anteriores')
end

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES DA CLI FORAM APROVADOS COM SUCESSO!           #{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
