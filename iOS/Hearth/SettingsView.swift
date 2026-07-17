import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager

    @State private var config: AppConfig?
    @State private var showPaywall = false

    private let websiteURL = URL(string: "https://shimondeitel.github.io/hearth-app/")!
    private let privacyURL = URL(string: "https://shimondeitel.github.io/hearth-app/privacy.html")!
    private let termsURL = URL(string: "https://shimondeitel.github.io/hearth-app/terms.html")!

    var body: some View {
        NavigationStack {
            Form {
                if let config {
                    Section {
                        DatePicker("First day",
                                   selection: Binding(
                                       get: { config.schoolYearStart },
                                       set: { config.schoolYearStart = $0; try? context.save() }),
                                   displayedComponents: .date)
                        DatePicker("Last day",
                                   selection: Binding(
                                       get: { config.schoolYearEnd },
                                       set: { config.schoolYearEnd = $0; try? context.save() }),
                                   displayedComponents: .date)
                        Stepper("Required days: \(config.requiredDays)",
                                value: Binding(
                                    get: { config.requiredDays },
                                    set: { config.requiredDays = $0; try? context.save() }),
                                in: 60...365)
                            .font(.nookRounded(15))
                    } header: {
                        Text("School year")
                            .accessibilityIdentifier("settingsHeader")
                    } footer: {
                        Text("Attendance exports count days and hours inside these dates against the required-days target your state uses.")
                    }
                }

                Section("Hearth Pro") {
                    if store.isPro {
                        Label("Pro is active. Thank you for keeping the fire lit.", systemImage: "checkmark.seal.fill")
                            .font(.nookRounded(14, weight: .medium))
                            .foregroundStyle(Color.forest)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Hearth Pro")
                                        .font(.nookRounded(15, weight: .semibold))
                                    Text("Unlimited kids plus PDF and CSV state reports")
                                        .font(.nookRounded(12))
                                        .foregroundStyle(Color.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(Color.lampGlow)
                            }
                        }
                        .accessibilityIdentifier("upgradeButton")
                    }
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    .accessibilityIdentifier("restoreButton")
                }

                Section("About") {
                    Link(destination: websiteURL) {
                        Label("Website", systemImage: "globe")
                    }
                    Link(destination: privacyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Link(destination: termsURL) {
                        Label("Terms of use", systemImage: "doc.text")
                    }
                } footer: {
                    Text("Hearth keeps every record on this device. Nothing is uploaded, tracked, or shared. Version 1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookBackground())
            .dismissesKeyboardOnTap()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear {
                if config == nil {
                    config = AppConfig.fetchOrCreate(in: context)
                }
            }
        }
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager

    private let privacyURL = URL(string: "https://shimondeitel.github.io/hearth-app/privacy.html")!
    private let termsURL = URL(string: "https://shimondeitel.github.io/hearth-app/terms.html")!

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(Color.lampGlow)
                            .padding(.top, 26)

                        Text("Hearth Pro")
                            .font(.nookTitle(30, weight: .bold))
                            .foregroundStyle(Color.ink)

                        Text("Everything a bigger family needs, still entirely on your device.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        VStack(alignment: .leading, spacing: 14) {
                            benefit(symbol: "person.3.fill",
                                    title: "Unlimited kids",
                                    detail: "Plan for the whole family. Free covers one learner.")
                            benefit(symbol: "doc.richtext.fill",
                                    title: "State-ready exports",
                                    detail: "Signed PDF attendance reports and CSV spreadsheets for compliance filing.")
                            benefit(symbol: "lock.shield.fill",
                                    title: "Still private",
                                    detail: "Pro adds features, never tracking. Data stays on device.")
                        }
                        .padding(20)
                        .windowPane()
                        .padding(.horizontal, 20)

                        Button {
                            Task {
                                await store.purchasePro()
                                if store.isPro { dismiss() }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(store.isPro ? "Pro is active" : "Subscribe")
                                    .font(.nookRounded(17, weight: .bold))
                                if let product = store.proProduct, !store.isPro {
                                    Text("\(product.displayPrice) per month, cancel anytime")
                                        .font(.nookRounded(12))
                                        .opacity(0.85)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.forest)
                            }
                            .foregroundStyle(Color.nookBackground)
                        }
                        .disabled(store.isPro || store.isLoading)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("subscribeButton")

                        Button("Restore purchases") {
                            Task {
                                await store.restore()
                                if store.isPro { dismiss() }
                            }
                        }
                        .font(.nookRounded(14, weight: .medium))
                        .foregroundStyle(Color.inkSoft)

                        HStack(spacing: 18) {
                            Link("Privacy", destination: privacyURL)
                            Link("Terms", destination: termsURL)
                        }
                        .font(.nookRounded(12))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.bottom, 30)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("closePaywallButton")
                }
            }
        }
    }

    private func benefit(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.honey)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nookRounded(15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
