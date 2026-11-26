import csv
import json
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
path = root / 'docs/food-image-manifest.csv'
with path.open(encoding='utf-8', newline='') as stream:
    rows = list(csv.DictReader(stream))
while True:
    try:
        data = json.loads((root / 'assets/data/vn_nutrition.json').read_text(encoding='utf-8'))
        break
    except json.JSONDecodeError:
        time.sleep(3)
foods = {food['id']: food for food in data['foods']}
recipes = {recipe['id']: recipe for recipe in data['recipes']}
known = {row['id'] for row in rows}
style = 'Realistic Vietnamese home-style food photography, 45-degree top-down angle, single serving on a plain off-white ceramic plate or bowl, soft natural window daylight from the left, very light warm grey background (#F6F7FC), shallow depth of field, appetizing, true-to-life portion size, clean composition centered with margin around the dish, no text, no logo, no hands, no people, no chopsticks crossing the dish, square 1:1, 1024x1024.'
for food in data['foods']:
    food_id = food['id']
    if food_id in known or (root / 'assets/food' / (food_id + '.webp')).exists():
        continue
    aka = '; '.join(food.get('aka', []))
    if food['group'] == 'mon_an' and food_id in recipes:
        recipe = recipes[food_id]
        ingredients = ', '.join(foods.get(item['food'], {}).get('name', item['food']) for item in recipe.get('ingredients', []))
        subject = 'Show the finished Vietnamese family dish using these ingredients: ' + ingredients + '. Preparation: ' + ' '.join(recipe.get('steps', []))
    else:
        subject = 'Show the food in its named form and preparation.'
    prompt = style + ' Subject: ' + food['name'] + ' (' + aka + '). ' + subject + ' No text, letters, numbers, labels, logos, brands, packaging, watermarks, hands, people, cutlery crossing food, extra unrelated foods, or non-Vietnamese props.'
    rows.append(dict(id=food_id, name=food['name'], group=food['group'], aka=aka, prompt=prompt, status='pending', notes=''))
with path.open('w', encoding='utf-8', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=['id', 'name', 'group', 'aka', 'prompt', 'status', 'notes'])
    writer.writeheader()
    writer.writerows(rows)
print(f'Manifest entries: {len(rows)}')
