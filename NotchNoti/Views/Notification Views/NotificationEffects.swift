//
//  NotificationEffects.swift
//  NotchNoti
//
//  Visual effects for enhanced notifications
//

import SwiftUI

// MARK: - 粒子效果视图（用于 celebration 类型）
struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    @State private var isActive = false  // 控制Timer激活

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle)
                }
            }
            .onAppear {
                createInitialParticles(in: geometry.size)
                isActive = true
            }
            .onDisappear {
                isActive = false  // 视图消失时停止更新
            }
            .onReceive(Timer.publish(every: isActive ? 0.1 : 3600, on: .main, in: .common).autoconnect()) { _ in
                guard isActive else { return }
                updateParticles()
                if particles.count < 15 { // 限制粒子数量以保持性能
                    addParticle(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false) // 不影响交互
    }
    
    private func createInitialParticles(in size: CGSize) {
        for _ in 0..<8 {
            particles.append(Particle(in: size))
        }
    }
    
    private func addParticle(in size: CGSize) {
        particles.append(Particle(in: size))
    }
    
    private func updateParticles() {
        particles = particles.compactMap { particle in
            var updated = particle
            updated.age += 0.1
            updated.y -= updated.velocity
            updated.x += updated.horizontalVelocity
            updated.opacity = max(0, 1.0 - (updated.age / updated.lifetime))
            
            return updated.age < updated.lifetime ? updated : nil
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
    var velocity: CGFloat
    var horizontalVelocity: CGFloat
    var age: Double = 0
    let lifetime: Double
    let symbol: String
    
    init(in size: CGSize) {
        self.x = CGFloat.random(in: 0...size.width)
        self.y = size.height / 2
        self.scale = CGFloat.random(in: 0.3...0.8)
        self.rotation = Double.random(in: 0...360)
        self.opacity = 1.0
        self.velocity = CGFloat.random(in: 1.5...3.0)
        self.horizontalVelocity = CGFloat.random(in: -0.5...0.5)
        self.lifetime = Double.random(in: 1.5...2.5)
        self.symbol = ["star.fill", "sparkle", "star.circle.fill"].randomElement()!
    }
}

struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        Image(systemName: particle.symbol)
            .font(.system(size: 12))
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0))
            .scaleEffect(particle.scale)
            .rotationEffect(.degrees(particle.rotation))
            .opacity(particle.opacity)
            .position(x: particle.x, y: particle.y)
            .animation(.linear(duration: 0.1), value: particle.y)
    }
}

// MARK: - 渐变背景视图
struct GradientBackgroundView: View {
    let type: NotchNotification.NotificationType
    @State private var gradientPhase: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            switch type {
            case .ai:
                // AI 类型使用动态渐变
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.3),
                        Color.blue.opacity(0.2),
                        Color.pink.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 1, y: gradientPhase)
                )
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                        gradientPhase = 1
                    }
                }
                
            case .celebration:
                // 庆祝类型使用金色渐变
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.84, blue: 0).opacity(0.2),
                        Color.orange.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
            case .security:
                // 安全类型使用红色渐变
                RadialGradient(
                    colors: [
                        Color.red.opacity(0.15),
                        Color.red.opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 100
                )
                
            case .success:
                // 成功类型使用绿色渐变
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.15),
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
            case .error:
                // 错误类型使用红色动态渐变
                RadialGradient(
                    colors: [
                        Color.red.opacity(0.2),
                        Color.orange.opacity(0.1),
                        Color.red.opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 80
                )
                
            default:
                Color.clear
            }
        }
        .cornerRadius(12)
    }
}

// MARK: - 光晕效果视图
struct GlowEffectView: View {
    let color: Color
    let intensity: Double
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .blur(radius: 20)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.3 : 0.6)
            .animation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - 进度指示器视图
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat = 3
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.interpolatingSpring(
                    mass: 0.5,
                    stiffness: 400,
                    damping: 25,
                    initialVelocity: 0
                ), value: progress)
        }
    }
}

// MARK: - 图标动画视图
struct AnimatedIconView: View {
    let type: NotchNotification.NotificationType
    let systemImage: String
    let color: Color
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkRotation: Double = -90
    @State private var shakeOffset: CGFloat = 0
    @State private var warningOpacity: Double = 1.0
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.0
    @State private var linkScale: CGFloat = 0.8
    @State private var toolRotation: Double = 0
    @State private var progressRotation: Double = 0
    
    var body: some View {
        ZStack {
            // 添加波纹效果背景（用于 info 类型）
            if type == .info {
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            rippleScale = 2.0
                            rippleOpacity = 0.0
                        }
                    }
            }
            
            Group {
                switch type {
                case .success:
                    // 成功图标勾号动画
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 2)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: systemImage)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                            .scaleEffect(checkmarkScale)
                            .rotationEffect(.degrees(checkmarkRotation))
                            .onAppear {
                                withAnimation(.interpolatingSpring(
                                    mass: 0.5,
                                    stiffness: 600,
                                    damping: 15,
                                    initialVelocity: 0
                                )) {
                                    checkmarkScale = 1.0
                                    checkmarkRotation = 0
                                }
                            }
                    }
                    
                case .error:
                    // 错误图标震动效果
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .offset(x: shakeOffset)
                        .onAppear {
                            withAnimation(.interpolatingSpring(
                                mass: 0.2,
                                stiffness: 1000,
                                damping: 5,
                                initialVelocity: 0
                            ).repeatCount(3, autoreverses: true)) {
                                shakeOffset = 4
                            }
                        }
                    
                case .warning:
                    // 警告图标脉冲闪烁
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .opacity(warningOpacity)
                        .shadow(color: color.opacity(0.5), radius: warningOpacity == 1.0 ? 8 : 2)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                warningOpacity = 0.4
                            }
                        }
                    
                case .info:
                    // 信息图标（带波纹效果）
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                isAnimating = true
                            }
                        }
                    
                case .hook:
                    // 钩子图标链接动画
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .scaleEffect(linkScale)
                        .onAppear {
                            withAnimation(.interpolatingSpring(
                                mass: 0.6,
                                stiffness: 400,
                                damping: 10,
                                initialVelocity: 0
                            )) {
                                linkScale = 1.0
                            }
                            // 添加持续的轻微脉冲
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                        linkScale = 1.1
                                    }
                                }
                            }
                        }
                    
                case .toolUse:
                    // 工具使用图标旋转
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(toolRotation))
                        .onAppear {
                            // 先转一圈然后小幅度摇摆
                            withAnimation(.easeInOut(duration: 0.5)) {
                                toolRotation = 360
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                        toolRotation = 375
                                    }
                                }
                            }
                        }
                    
                case .progress:
                    // 进度图标循环旋转
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [color.opacity(0.2), color.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(progressRotation))
                        
                        Image(systemName: systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            progressRotation = 360
                        }
                    }
                    
                case .sync:
                    // 同步图标旋转
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                    
                case .download, .upload:
                    // 上传下载图标跳动
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .offset(y: bounceOffset)
                        .onAppear {
                            withAnimation(.interpolatingSpring(
                                mass: 0.5,
                                stiffness: 500,
                                damping: 10,
                                initialVelocity: 0
                            ).repeatForever(autoreverses: true)) {
                                bounceOffset = type == .download ? 3 : -3
                            }
                        }
                    
                case .reminder:
                    // 提醒图标摇摆
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(isAnimating ? 10 : -10))
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                        .onAppear {
                            isAnimating = true
                        }
                    
                case .ai:
                    // AI 图标脉冲
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                pulseScale = 1.1
                            }
                        }
                    
                case .security:
                    // 安全图标闪烁
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .opacity(isAnimating ? 1.0 : 0.6)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                        .onAppear {
                            isAnimating = true
                        }
                    
                case .celebration:
                    // 庆祝图标缩放弹跳
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                        .scaleEffect(pulseScale)
                        .rotationEffect(.degrees(isAnimating ? 10 : -10))
                        .onAppear {
                            withAnimation(.interpolatingSpring(
                                mass: 0.5,
                                stiffness: 500,
                                damping: 8,
                                initialVelocity: 0
                            )) {
                                pulseScale = 1.2
                            }
                            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                                isAnimating = true
                            }
                        }
                }
            }
        }
    }
    
    private func startAnimation() {
        isAnimating = true
    }
}

// MARK: - 进度通知视图扩展
extension NotchNotification {
    var progressValue: Double? {
        typedMetadata.progress
    }
    
    var hasSpecialBackground: Bool {
        switch type {
        case .ai, .celebration, .security, .success, .error:
            return true
        default:
            return false
        }
    }
    
    var hasParticleEffect: Bool {
        type == .celebration
    }
    
    var hasGlowEffect: Bool {
        priority == .urgent || type == .security || type == .error || type == .success
    }
    
    var hasAnimatedIcon: Bool {
        // 现在所有类型都有动画效果了！
        return true
    }
}