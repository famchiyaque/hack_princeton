import SwiftUI

struct HomeView: View {
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("FormCoach")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Real-time workout coaching")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        NavigationLink(destination: SessionView()) {
                            Label("Start Workout", systemImage: "play.fill")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.green, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }

                        Button {
                            showHistory = true
                        } label: {
                            Label("Session History", systemImage: "clock.arrow.circlepath")
                                .font(.body.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }
}
