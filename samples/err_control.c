/* Demonstração de erros sintáticos em if, else, while e for */
int main() {
    int x = 5;
    int i = 0;

    if x > 0 {
        x = x - 1;
    }

    while (x > 0 {
        x = x - 1;
    }

    for (i = 0 i < 10; i++) {
        x = x + i;
    }

    else {
        x = 0;
    }

    return 0;
}
