import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var currentRole: UserRole
    @Binding var currentUsername: String
    @AppStorage("appLang") private var lang = "tr"

    @State private var selectedRole: UserRole = .admin
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animate = false
    @State private var profileImage: NSImage? = nil

    @AppStorage("lastLoggedInUser") private var lastLoggedInUser: String = ""
    @AppStorage("lastLoggedInRole") private var lastLoggedInRole: String = ""
    @AppStorage("lastLoggedInAvatarPath") private var lastLoggedInAvatarPath: String = ""

    // Mac'teki oturum açmış sistem kullanıcısının adı (otomatik, manuel giriş gerekmez)
    private let systemFullName: String = {
        let name = NSFullUserName()
        return name.isEmpty ? NSUserName() : name
    }()

    var body: some View {
        ZStack {
            // Arka plan gradyanı
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.11), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animasyonlu ışımalar
            Circle().fill(Color.blue.opacity(0.22)).blur(radius: 130).frame(width: 420, height: 420)
                .offset(x: animate ? -150 : 150, y: animate ? -150 : 150)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            Circle().fill(Color.purple.opacity(0.2)).blur(radius: 130).frame(width: 420, height: 420)
                .offset(x: animate ? 150 : -150, y: animate ? 150 : -150)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)

            VStack(spacing: 36) {
                // LOGO
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .opacity(0.15)
                            .blur(radius: 12)
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    Text("NEXUS ANALYTICS")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(5)
                    Text("Güvenli Erişim Portalı")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 36)

                // GİRİŞ KUTUSU
                VStack(spacing: 22) {
                    if !lastLoggedInUser.isEmpty {
                        fastLoginView
                    } else {
                        normalLoginView
                    }
                }
                .padding(32)
                .frame(width: 340)
                .background(.ultraThinMaterial)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)

                Spacer()
            }
        }
        .onAppear {
            animate = true
            loadAvatarFromDisk()
            // Kaydedilmiş özel bir avatar yoksa Mac hesabındaki profil fotoğrafını otomatik dene
            if profileImage == nil {
                profileImage = fetchSystemAccountImage()
            }
        }
        .frame(minWidth: 750, minHeight: 650)
    }

    // MARK: - Hızlı giriş (daha önce giriş yapmış kullanıcı)
    private var fastLoginView: some View {
        VStack(spacing: 18) {
            avatarView(size: 92)
                .onTapGesture { pickAvatarImage() }

            VStack(spacing: 4) {
                Text(lastLoggedInUser)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(lastLoggedInRole == "admin" ? "Yönetici" : "Çalışan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            SecureField("Parolanız", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit(processFastLogin)

            if showError {
                Text(errorMessage).font(.caption).foregroundColor(.red)
            }

            Button(action: processFastLogin) {
                Text("Giriş Yap").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 250)

            Button {
                AuthenticationManager.shared.authenticateForLogin { success in
                    if success { withAnimation { isLoggedIn = true } }
                }
            } label: {
                Label("Touch ID ile Giriş", systemImage: "touchid")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            Button("Başka Hesapla Giriş Yap") {
                lastLoggedInUser = ""
                lastLoggedInRole = ""
                lastLoggedInAvatarPath = ""
                profileImage = nil
                password = ""
            }
            .buttonStyle(.plain)
            .font(.caption2)
            .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Normal giriş (ilk kez / başka hesap)
    private var normalLoginView: some View {
        VStack(spacing: 18) {
            avatarView(size: 76)
                .onTapGesture { pickAvatarImage() }

            VStack(spacing: 2) {
                Text("Hoş geldin, \(systemFullName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Text("Sisteme Giriş")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Picker("", selection: $selectedRole) {
                Text("Admin").tag(UserRole.admin)
                Text("Employee").tag(UserRole.employee)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            TextField("Kullanıcı Adı", text: $username)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            SecureField("Parola", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit(validateLogin)

            if showError {
                Text(errorMessage).font(.caption).foregroundColor(.red)
            }

            Button(action: validateLogin) {
                Text("Güvenli Giriş").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 250)
        }
    }

    // MARK: - Avatar görünümü
    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)

            if let profileImage {
                Image(nsImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                let displayName = !lastLoggedInUser.isEmpty ? lastLoggedInUser
                    : (!username.isEmpty ? username : systemFullName)
                Text(String(displayName.isEmpty ? "?" : displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(.white)
            }

            // Fotoğrafın değiştirilebilir olduğunu belli eden küçük kamera rozeti
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.15))
                        .foregroundColor(.white)
                )
                .offset(x: size * 0.36, y: size * 0.36)
        }
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(radius: 8)
    }

    /// Mac hesabında tanımlı profil fotoğrafını (Sistem Ayarları > Kullanıcılar) otomatik olarak okur.
    /// Manuel bir işlem gerektirmez; fotoğraf yoksa nil döner ve baş harfe düşülür.
    private func fetchSystemAccountImage() -> NSImage? {
        let task = Process()
        task.launchPath = "/usr/bin/dscl"
        task.arguments = [".", "-read", "/Users/\(NSUserName())", "JPEGPhoto"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // hataları sessizce yut

        do {
            try task.run()
        } catch {
            return nil
        }
        task.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8), !output.isEmpty else { return nil }

        // dscl çıktısı şu formatta gelir: "JPEGPhoto:\n <hex baytlar satır satır>"
        let lines = output.components(separatedBy: "\n").dropFirst()
        let hexString = lines.joined().replacingOccurrences(of: " ", with: "")
        guard !hexString.isEmpty, let imageData = Data(hexString: hexString) else { return nil }

        return NSImage(data: imageData)
    }

    private func pickAvatarImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Profil Fotoğrafı Seç"

        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            profileImage = image
            saveAvatarToDisk(image: image, forUser: lastLoggedInUser.isEmpty ? username : lastLoggedInUser)
        }
    }

    private func avatarDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("NexusAnalytics/Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveAvatarToDisk(image: NSImage, forUser user: String) {
        guard !user.isEmpty,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }

        let fileURL = avatarDirectory().appendingPathComponent("\(user).png")
        try? data.write(to: fileURL)
        lastLoggedInAvatarPath = fileURL.path
    }

    private func loadAvatarFromDisk() {
        guard !lastLoggedInAvatarPath.isEmpty,
              FileManager.default.fileExists(atPath: lastLoggedInAvatarPath) else { return }
        profileImage = NSImage(contentsOfFile: lastLoggedInAvatarPath)
    }

    // MARK: - Mantıksal fonksiyonlar
    private func validateLogin() {
        if username.isEmpty || password.isEmpty { errorMessage = "Boş alanları doldurun"; showError = true; return }
        if selectedRole == .admin {
            if username.lowercased() == "admin" && password == "1234" { executeLogin(user: "Admin Yönetici", role: .admin, storageRole: "admin") }
            else { errorMessage = "Hatalı!"; showError = true }
        } else {
            if password == "1234" { executeLogin(user: username, role: .employee, storageRole: "employee") }
            else { errorMessage = "Parola hatalı!"; showError = true }
        }
    }

    private func processFastLogin() {
        if password == "1234" {
            currentRole = lastLoggedInRole == "admin" ? .admin : .employee
            currentUsername = lastLoggedInUser
            isLoggedIn = true
        } else {
            errorMessage = "Parola hatalı!"
            showError = true
            password = ""
        }
    }

    private func executeLogin(user: String, role: UserRole, storageRole: String) {
        lastLoggedInUser = user
        lastLoggedInRole = storageRole
        currentRole = role
        currentUsername = user
        isLoggedIn = true
        loadAvatarFromDisk()
    }
}

// MARK: - Yeniden kullanılabilir cam kart modifier'ı
extension View {
    func loginGlassCard() -> some View {
        self.modifier(LoginGlassCardModifier())
    }
}

// MARK: - Hex string -> Data yardımcı fonksiyonu (dscl çıktısını çözmek için)
extension Data {
    init?(hexString: String) {
        var data = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            guard let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) else { return nil }
            let byteString = hexString[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

struct LoginGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}
