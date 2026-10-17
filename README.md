# Safira

Um compilador didático escrito em **Ruby puro**, que analisa código-fonte em C
e mostra cada etapa do processo no terminal.

Projeto da disciplina de **Compiladores (2026.2)**.

O Safira faz as três análises clássicas de um compilador — **léxica**,
**sintática** e **semântica** — e apresenta o resultado de cada uma com tabelas,
árvores e diagnósticos coloridos bem bonitos :)

---

## Requisitos

- **Ruby 3.2 ou superior**

```bash
ruby -v
```

---

## Como usar

Execute direto na raiz do projeto passando um arquivo `.c`:

```bash
ruby safira.rb samples/valid.c
```

E flags opcionais para ver uma etapa isolada:

```bash
ruby safira.rb samples/valid.c --tokens     # só a lista de tokens
ruby safira.rb samples/valid.c --symbols    # só a tabela de símbolos
ruby safira.rb samples/valid.c --ast        # só a árvore sintática
ruby safira.rb samples/valid.c --semantic   # só a análise semântica
```

---

## Autores

- **Leonardo da Silva Badauê** ([@enqora](https://github.com/enqora))
- **Micael Melo** ([@MeloMicael](https://github.com/MeloMicael))
