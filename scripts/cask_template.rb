cask "yc-clipboard" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "__DOWNLOAD_URL__"
  name "yc.clipboard"
  desc "Lightweight macOS clipboard manager"
  homepage "https://github.com/yceffort/mac-clipboard"

  app "yc.clipboard.app"

  zap trash: [
    "~/Library/Application Support/yceffort Clipboard",
  ]
end
