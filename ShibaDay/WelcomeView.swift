//
//  WelcomeView.swift
//  bearsapp
//
//  Created by Irina on 17.09.26.
//

import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("ShibaDay")
                .font(.system(
                    size: 46,
                    weight: .heavy,
                    design: .rounded
                ))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("brandOrange"))
                .accessibilityAddTraits(.isHeader)
            
            
            Spacer()
            
            Button(action: onDone) {
                Text("Get Started")
                    .font(.system(
                        size: 18,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(Color("brandOrange"), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your daily planner")
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { geometry in
                Image("welcomebackground")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    WelcomeView(onDone: {})
}
