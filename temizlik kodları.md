"Flutter Temizlik Komutları" başlıklı listenizi oluşturdum. Bu listede platformları devre dışı bırakmak, gereksiz dosyaları silmek ve disk alanını kontrol etmek için ihtiyacınız olan tüm terminal komutlarını bulabilirsiniz.

flutter config --no-enable-linux --no-enable-macos --no-enable-windows --no-enable-web --no-enable-ios
rm -rf linux/ macos/ windows/ ios/ web/
flutter clean
flutter pub cache clean
rm -rf ~/.pub-cache
rm -rf android/.gradle android/app/build
df -h /home
