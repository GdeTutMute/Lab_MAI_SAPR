print("Night labs speedrun")
n = 4
for i in range(n):
    # Левые пробелы
    spaces = ' ' * (n - i - 1)
    # Звезды
    stars = '*' * (2 * i + 1)
    # Правые пробелы
    right_spaces = ' ' * (n - i - 1)
    
    print(spaces + stars + right_spaces)
print("sverhu piramida))")