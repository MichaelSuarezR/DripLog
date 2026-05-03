-- Repair inspiration_looks metadata after CSV import dropped array columns.
begin;

alter table public.inspiration_looks
add column if not exists filename text;

update public.inspiration_looks
set filename = split_part(image_url, '/', array_length(string_to_array(image_url, '/'), 1))
where filename is null or filename = '';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White camisole with denim mini skirt and white sneakers.',
  categories = ARRAY['camisole', 'mini skirt', 'sneakers'],
  weather = ARRAY['hot', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'blue'],
  gender = 'women'
where filename = '50b26897decb50334984ad7b5a1b566f.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White fitted tee with striped shorts, cap, and sneakers.',
  categories = ARRAY['t-shirt', 'shorts', 'cap', 'sneakers'],
  weather = ARRAY['hot', 'warm'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'green', 'multicolor'],
  gender = 'women'
where filename = 'a493c3f6d16a2410efd5eb799cc14ce4.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Black polka-dot top with denim shorts, knee boots, and white bag.',
  categories = ARRAY['top', 'shorts', 'boots', 'handbag'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'going out'],
  colors = ARRAY['black', 'blue', 'white', 'brown'],
  gender = 'women'
where filename = 'b7eb72cce85a3da0644518572c3170c3.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Striped button-up with denim mini skirt and mary jane shoes.',
  categories = ARRAY['button-up', 'mini skirt', 'mary janes', 'socks'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['blue', 'white', 'green', 'black'],
  gender = 'women'
where filename = 'd4ab53e797d14db4835f2dab317df793.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White tank with loose white pants and shoulder bag.',
  categories = ARRAY['tank top', 'trousers', 'handbag'],
  weather = ARRAY['hot', 'sunny'],
  occasion = ARRAY['casual', 'vacation'],
  colors = ARRAY['white', 'black', 'brown'],
  gender = 'women'
where filename = '3570e479d09fd96393d7493de07cfb75.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Asymmetric cream top with white shorts and flats.',
  categories = ARRAY['top', 'shorts', 'flats', 'handbag'],
  weather = ARRAY['hot', 'warm'],
  occasion = ARRAY['going out', 'daytime'],
  colors = ARRAY['cream', 'white', 'brown', 'gold'],
  gender = 'women'
where filename = '7c7ba5353c2465d4b18775fe20a33fad.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Oversized gray hoodie with dark wide-leg jeans and beanie.',
  categories = ARRAY['hoodie', 'jeans', 'beanie'],
  weather = ARRAY['cold'],
  occasion = ARRAY['casual', 'cozy'],
  colors = ARRAY['gray', 'blue', 'black'],
  gender = 'women'
where filename = 'aeb0a5f9359cb3391c3a7c8a28c93679.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Dark oversized jacket layered over hoodie with baggy pants and sneakers.',
  categories = ARRAY['jacket', 'hoodie', 'jeans', 'sneakers', 'handbag'],
  weather = ARRAY['cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['black', 'charcoal', 'white', 'brown'],
  gender = 'women'
where filename = 'b6d63ee372ed152a2a4d2672f7284dbd.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Off-shoulder cream sweater with loose blue jeans and clogs.',
  categories = ARRAY['sweater', 'jeans', 'clogs', 'handbag'],
  weather = ARRAY['cold', 'cool'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['cream', 'blue', 'brown'],
  gender = 'women'
where filename = 'f9df8d6653abecc75264fa280c200d49.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Leather jacket with black jeans, scarf, cap, and sneakers.',
  categories = ARRAY['leather jacket', 'jeans', 'scarf', 'cap', 'sneakers', 'handbag'],
  weather = ARRAY['cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['black', 'white', 'green'],
  gender = 'women'
where filename = 'f3491f8ce3d27ec717af5af004e573cb.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Leather jacket over gray hoodie with baggy jeans and headband.',
  categories = ARRAY['leather jacket', 'hoodie', 'jeans', 'headband', 'handbag'],
  weather = ARRAY['cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['black', 'gray', 'blue'],
  gender = 'women'
where filename = 'bcf51029499a6c453f0210362f45a548.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Puffer vest layered over sweatshirt with loose green jeans and clogs.',
  categories = ARRAY['puffer vest', 'sweatshirt', 'jeans', 'clogs', 'handbag'],
  weather = ARRAY['cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['gray', 'green', 'brown', 'black'],
  gender = 'women'
where filename = '2b480405cc713ad63e075fe1bf20664b.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Black tank bodysuit with denim mini skirt, leather jacket, and tall boots.',
  categories = ARRAY['tank top', 'mini skirt', 'leather jacket', 'boots', 'handbag'],
  weather = ARRAY['cool', 'night'],
  occasion = ARRAY['going out', 'date night'],
  colors = ARRAY['black', 'blue', 'brown'],
  gender = 'women'
where filename = '1d40b442a46f101ed8c5a00e369dec86.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Oversized graphic tee with denim shorts and tall boots for a night-out look.',
  categories = ARRAY['graphic tee', 'shorts', 'boots', 'handbag'],
  weather = ARRAY['warm', 'night'],
  occasion = ARRAY['going out', 'concert'],
  colors = ARRAY['brown', 'blue', 'beige'],
  gender = 'women'
where filename = 'e3c91ad173b1fd0179366a14ac5a25b1.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Brown bodysuit with dark flared jeans and shoulder bag.',
  categories = ARRAY['bodysuit', 'jeans', 'handbag'],
  weather = ARRAY['warm', 'night'],
  occasion = ARRAY['going out', 'date night'],
  colors = ARRAY['brown', 'black'],
  gender = 'women'
where filename = '15c679ae770a58eb291be71db7cff8e3.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Oversized leather jacket with denim mini skirt and tall black boots.',
  categories = ARRAY['leather jacket', 'mini skirt', 'boots'],
  weather = ARRAY['cool', 'night'],
  occasion = ARRAY['going out', 'date night'],
  colors = ARRAY['black', 'blue'],
  gender = 'women'
where filename = '249b50e6fcd80f529aece36a3004ff92.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Burgundy corset top with dark pinstripe trousers and scarf.',
  categories = ARRAY['corset top', 'trousers', 'scarf', 'handbag', 'heels'],
  weather = ARRAY['warm', 'daytime'],
  occasion = ARRAY['going out', 'date night'],
  colors = ARRAY['burgundy', 'black', 'white'],
  gender = 'women'
where filename = 'b97f8667328d2db71306ee116c34718e.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Black halter top with loose light-wash jeans and black heels.',
  categories = ARRAY['halter top', 'jeans', 'heels'],
  weather = ARRAY['warm', 'night'],
  occasion = ARRAY['going out', 'dinner'],
  colors = ARRAY['black', 'beige'],
  gender = 'women'
where filename = '047d6b037f8b4428c5f00d4ec655e058.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Burgundy off-shoulder top with wide-leg jeans and heels.',
  categories = ARRAY['top', 'jeans', 'heels', 'handbag', 'belt'],
  weather = ARRAY['warm', 'night'],
  occasion = ARRAY['going out', 'date night'],
  colors = ARRAY['burgundy', 'blue', 'black'],
  gender = 'women'
where filename = 'c0fb2e8ec7771a334718d8e3be7ae309.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Red glossy cami with baggy light-wash jeans and sneakers.',
  categories = ARRAY['tank top', 'jeans', 'sneakers', 'handbag'],
  weather = ARRAY['warm', 'night'],
  occasion = ARRAY['going out', 'party'],
  colors = ARRAY['red', 'blue', 'white'],
  gender = 'women'
where filename = '5d5d02a40db1431162ed8c4794026db0.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Tan vest over black long-sleeve top with loose jeans and boots.',
  categories = ARRAY['vest', 'long-sleeve', 'jeans', 'cap', 'boots', 'handbag'],
  weather = ARRAY['cool'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['tan', 'black', 'blue', 'brown'],
  gender = 'women'
where filename = '7935d5902e3d1701386ae3f38c9ab8d9.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Blue and white track jacket with oversized jeans and sneakers.',
  categories = ARRAY['track jacket', 'jeans', 'sneakers', 'glasses'],
  weather = ARRAY['cool'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['blue', 'white'],
  gender = 'women'
where filename = '55969a711eaa10b0fd9e97897176e43e.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Olive cropped sweatshirt with long denim shorts, cap, and sneakers.',
  categories = ARRAY['sweatshirt', 'shorts', 'cap', 'sneakers', 'handbag'],
  weather = ARRAY['warm'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['olive', 'blue', 'yellow', 'brown'],
  gender = 'women'
where filename = 'f570b96b10c2c47b268b7e41bd1e2108.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Red graphic tee with long denim shorts and white sneakers.',
  categories = ARRAY['graphic tee', 'shorts', 'sneakers', 'socks'],
  weather = ARRAY['hot', 'warm'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['red', 'blue', 'white'],
  gender = 'men'
where filename = '8f8ca9f67e7765e501e067d40c3c8c33.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Navy sweater with gray long shorts, beret, and clogs.',
  categories = ARRAY['sweater', 'shorts', 'beret', 'clogs', 'socks'],
  weather = ARRAY['cool'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['navy', 'gray', 'beige', 'white'],
  gender = 'men'
where filename = '6363fc71a6550240dc0ab705be4ea56d.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Black plaid button-up with oversized dark trousers and white sneakers.',
  categories = ARRAY['button-up', 'trousers', 'sneakers', 't-shirt'],
  weather = ARRAY['cool', 'night'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['black', 'white', 'charcoal'],
  gender = 'men'
where filename = 'ee82cf59bcf14627f39e28399ebf3c23.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Light blue tee with light-wash wide-leg jeans and flip-flops.',
  categories = ARRAY['t-shirt', 'jeans', 'flip-flops'],
  weather = ARRAY['hot', 'sunny'],
  occasion = ARRAY['casual', 'vacation'],
  colors = ARRAY['blue', 'light blue', 'green'],
  gender = 'men'
where filename = 'cf24d628b933c996abf41d823d55cb0c.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Football jersey with dark long shorts, socks, and clogs.',
  categories = ARRAY['jersey', 'shorts', 'socks', 'clogs'],
  weather = ARRAY['warm'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['brown', 'white', 'black', 'beige'],
  gender = 'men'
where filename = '70ac4ac43ed68fd3ca6f68a9f12319f7.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White linen button-up with light jeans, cap, and white sneakers.',
  categories = ARRAY['button-up', 'jeans', 'cap', 'sneakers', 'sunglasses'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'blue', 'green'],
  gender = 'men'
where filename = 'd0bad968937e1c2352c80a68edc77ed8.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White graphic tee with blue jeans and brown loafers.',
  categories = ARRAY['graphic tee', 'jeans', 'loafers', 'belt'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'blue', 'brown', 'red'],
  gender = 'men'
where filename = '6e43fb72c24fa546d03bc684143d0a7f.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Brown jacket over cream knit sweater with light-wash jeans and red sneakers.',
  categories = ARRAY['jacket', 'sweater', 'jeans', 'cap', 'sneakers'],
  weather = ARRAY['cool', 'cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['brown', 'cream', 'blue', 'red'],
  gender = 'men'
where filename = '0632f5e761e4556be904c62ba269f2a6.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Blue sweater layered over collared shirt with jeans and brown boots.',
  categories = ARRAY['sweater', 'collared shirt', 'jeans', 'boots', 'handbag'],
  weather = ARRAY['cool'],
  occasion = ARRAY['smart casual', 'daytime'],
  colors = ARRAY['blue', 'light blue', 'brown'],
  gender = 'men'
where filename = '2657ff1a7b7e36a49c85ab7a65416f86.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Blue plaid overshirt with gray tank, wide-leg jeans, and white sneakers.',
  categories = ARRAY['overshirt', 'tank top', 'jeans', 'sneakers'],
  weather = ARRAY['warm', 'cool'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['blue', 'gray', 'white'],
  gender = 'men'
where filename = '32b4cee358337a8df6b80bf8f92799cd.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Light blue knit sweater with dark jeans and brown shoes.',
  categories = ARRAY['sweater', 'jeans', 'shoes'],
  weather = ARRAY['cool', 'cold'],
  occasion = ARRAY['smart casual', 'daytime'],
  colors = ARRAY['light blue', 'navy', 'brown'],
  gender = 'men'
where filename = 'fbfb5d609c0e2d23e9a5944de78d804b.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White button-up with denim shorts, cap, and yellow sneakers.',
  categories = ARRAY['button-up', 'shorts', 'cap', 'sneakers', 'socks'],
  weather = ARRAY['hot', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'blue', 'yellow', 'black'],
  gender = 'men'
where filename = '206939ca0430860279bfbd204dc2773f.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Short-sleeve patterned button-up with dark long shorts and clogs.',
  categories = ARRAY['button-up', 'shorts', 'clogs', 'socks'],
  weather = ARRAY['warm'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['beige', 'brown', 'charcoal', 'white'],
  gender = 'men'
where filename = 'fccc04c3cf08ff42cdbb4f9bec0cb781.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Black cardigan over white polo with light-wash jeans and belt.',
  categories = ARRAY['cardigan', 'polo', 'jeans', 'belt', 'sunglasses'],
  weather = ARRAY['cool'],
  occasion = ARRAY['smart casual', 'daytime'],
  colors = ARRAY['black', 'white', 'blue'],
  gender = 'men'
where filename = '6e15ae3a9b315a85add5516669559021.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Taupe knit sweater with dark wide-leg trousers, cap, and boots.',
  categories = ARRAY['sweater', 'trousers', 'cap', 'boots'],
  weather = ARRAY['cool', 'cold'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['taupe', 'black', 'blue', 'brown'],
  gender = 'men'
where filename = '3c254d1649af77de8dc99da5ce1a8dfe.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Fitted black tee with pleated black trousers and black loafers.',
  categories = ARRAY['t-shirt', 'trousers', 'loafers', 'belt'],
  weather = ARRAY['warm'],
  occasion = ARRAY['smart casual', 'night out'],
  colors = ARRAY['black'],
  gender = 'men'
where filename = '266c5724c0dfda43877bb88e20b1845d.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Yellow graphic tee with cream baggy jeans, green cap, and black shoes.',
  categories = ARRAY['graphic tee', 'jeans', 'cap', 'shoes', 'handbag'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['yellow', 'cream', 'green', 'black'],
  gender = 'men'
where filename = 'bb6379b8891dbdb667934754d800a914.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Pale yellow graphic tee with light-wash wide-leg jeans and suede clogs.',
  categories = ARRAY['graphic tee', 'jeans', 'clogs'],
  weather = ARRAY['warm', 'sunny'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['yellow', 'blue', 'beige', 'green'],
  gender = 'men'
where filename = 'c0c3ed7769d8bd9c337265fd01d2edad.jpg';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'Green knit sweater with loose light-wash jeans and white sneakers.',
  categories = ARRAY['sweater', 'jeans', 'sneakers', 'handbag'],
  weather = ARRAY['cool', 'cold'],
  occasion = ARRAY['casual', 'streetwear'],
  colors = ARRAY['green', 'blue', 'white'],
  gender = 'men'
where filename = 'download.png';

update public.inspiration_looks
set
  source_name = 'Curated',
  caption = 'White tee with denim shorts, green cap, and brown clogs.',
  categories = ARRAY['t-shirt', 'shorts', 'cap', 'clogs', 'socks'],
  weather = ARRAY['hot', 'warm'],
  occasion = ARRAY['casual', 'daytime'],
  colors = ARRAY['white', 'blue', 'green', 'brown'],
  gender = 'men'
where filename = 'download (1).png';

commit;
