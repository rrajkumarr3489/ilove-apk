# Media folder – https://api.flaumingospharma.com/media/

Ella images-um intha ONE folder-la podunga. File name EXACT-aa (small letters) irukkanum.
Image illati app crash aagathu – illustration/icon fallback kaattum.

## 1. Home banners (slide show) – 3 to 5 images
Sizes: 1080 x 750 px (full width, 1.44:1), JPG, each <= 250 KB
Mukkiyam: mukkiya porul (kovil, name board) NADUVULA irukkanum. Mela 25% header wave-la konjam maraiyum, keezha 15% cream-aa fade aagum.
Names: File1.jpg, File2.jpg, File3.jpg (already irukku)
Add more: SQL -> Home.Banners = 'File1.jpg|Aruppukottai|அருப்புக்கோட்டை,File2.jpg,File3.jpg'
Idea: kovil gopuram, town main road, Aruppukottai famous place photos.

## 2. Service tiles (10 icons) – transparent PNG
Size: 256 x 256 px, PNG with transparent background, each <= 40 KB
Style: mockup-la ulla maathiri colourful cartoon illustration.
| File | Tile |
|---|---|
| tile_news.png | News / செய்திகள் |
| tile_bus.png | Bus Timings / பேருந்து |
| tile_train.png | Train / ரயில் |
| tile_services.png | Local Services / சேவைகள் |
| tile_parcel.png | Parcel / பார்சல் |
| tile_shops.png | Shops / கடைகள் |
| tile_food.png | Food / உணவு |
| tile_temples.png | Temples / கோயில்கள் |
| tile_report.png | Report / புகார் |
| tile_ai.png | AI Help / AI உதவி |
(Tile key names: DB Sections table-la ulla key-ye use pannum; ithu mismatch-na andha tile-ku icon fallback varum.)

## 3. News (Today's news) – ippo DATABASE-la irundhu varum
Photo: 400 x 300 px (4:3), JPG, each <= 60 KB, media folder-la (news1.jpg, news2.jpg ...)
News text: SQL table dbo.News (TitleEn / TitleTa thaniya). news.json ippo thevai illa.
Pudhu news add: INSERT INTO dbo.News (TitleEn, TitleTa, ImageFile, PublishedOn) VALUES (N'English', N'தமிழ்', N'news3.jpg', '2026-10-27');

## 4. Logo / launcher icon
Already app-kulla irukku (assets). Mari matha venumna sollunga.
