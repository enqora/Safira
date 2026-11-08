# S✧fira

Compilador didático desenvolvido em Ruby puro para um subconjunto da linguagem C. Projeto da disciplina de Compiladores (2026.2).

O programa lê um arquivo de código C e executa as três etapas principais diretamente no terminal: análise léxica (com tabela de símbolos), análise sintática (árvore sintática com recuperação de erros) e análise semântica (checagem de tipos e escopo).

## O que o compilador suporta

- Tipos primitivos: `int`, `float`, `char`, `double` e `void`.
- Declarações de variáveis e atribuições simples e compostas (`+=`, `-=`).
- Pré e pós-incremento e decremento (`++`, `--`).
- Expressões aritméticas, relacionais e lógicas com precedência de operadores.
- Estruturas de controle de fluxo: `if`, `else`, `while` e `for`.
- Definição de funções com parâmetros e comando `return`.
- Descarte de comentários (`//` e `/* */`) e diretivas de pré-processador (`#include`, `#define`).

## Requisitos

- Ruby 3.2 ou superior (uso de `Data.define`).

```bash
ruby -v
```

## Como usar

Execute o compilador passando o caminho de um arquivo `.c`:

```bash
ruby safira.rb samples/valid.c
```

Também é possível visualizar apenas uma etapa específica com flags:

```bash
ruby safira.rb samples/valid.c --tokens     # Lista de tokens
ruby safira.rb samples/valid.c --symbols    # Tabela de símbolos
ruby safira.rb samples/valid.c --ast        # Árvore sintática
ruby safira.rb samples/valid.c --semantic   # Análise semântica
```

Outras opções: `--no-color` (desativa cores ANSI) e `--help`.

## Testes

Para executar toda a suíte de testes:

```bash
for f in tests/test_*.rb; ruby $f; end
```

Ou rodar um arquivo de teste específico:

```bash
ruby tests/test_lexer.rb
ruby tests/test_parser.rb
ruby tests/test_semantic.rb
ruby tests/test_compiler.rb
ruby tests/test_control.rb
ruby tests/test_semicolon.rb
```

## Autores

- Leonardo Badauê ([@enqora](https://github.com/enqora))
- Micael Melo ([@MeloMicael](https://github.com/MeloMicael))
- Yan Mota ([@Neves08](https://github.com/Neves08))
- Lucas Kelvim ([@Lucaksc777](https://github.com/Lucaksc777))
