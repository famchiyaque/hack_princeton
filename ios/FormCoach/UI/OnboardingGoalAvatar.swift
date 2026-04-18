import SwiftUI

/// Looping motion avatars for onboarding goal tiles (GIF-style motion, no image assets required).
struct OnboardingGoalAvatarView: View {
    let goalId: String
    var isSelected: Bool

    private var ink: Color { isSelected ? .white : .black }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Group {
                switch goalId {
                case "bodybuilding": bodybuildingArm(t: t)
                case "strength": strengthLift(t: t)
                case "longevity": longevityHeart(t: t)
                case "fat_loss": fatLossScale(t: t)
                case "athleticism": athleticismRun(t: t)
                case "aesthetic": aestheticMirrorFlex(t: t)
                case "physical_rehab": rehabBandaid(t: t)
                default:
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }
            .frame(width: 30, height: 30)
        }
    }

    // MARK: - Bodybuilding — bicep contracting (elbow flex)

    private func bodybuildingArm(t: Double) -> some View {
        let flex = (sin(t * 2.2) + 1) / 2 // 0 relaxed … 1 flexed
        let elbowDeg = 165 - flex * 75

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let shoulder = CGPoint(x: w * 0.22, y: h * 0.42)
            let elbow = CGPoint(x: w * 0.48, y: h * 0.38 + flex * 4)
            let rad = elbowDeg * .pi / 180
            let forearmLen = w * 0.42
            let hand = CGPoint(
                x: elbow.x + cos(rad) * forearmLen,
                y: elbow.y + sin(rad) * forearmLen
            )

            var upper = Path()
            upper.move(to: shoulder)
            upper.addLine(to: elbow)
            ctx.stroke(upper, with: .color(ink), lineWidth: 2.2)

            var fore = Path()
            fore.move(to: elbow)
            fore.addLine(to: hand)
            ctx.stroke(fore, with: .color(ink), lineWidth: 2.2)

            // Simple “bicep” bulge when flexed
            if flex > 0.35 {
                let bulge = CGRect(x: w * 0.32, y: h * 0.28, width: w * 0.14 * flex, height: h * 0.22)
                ctx.fill(Path(ellipseIn: bulge), with: .color(ink.opacity(0.2 + flex * 0.25)))
            }
        }
    }

    // MARK: - Strength — stick figure lifting barbell

    private func strengthLift(t: Double) -> some View {
        let lift = (sin(t * 1.8) + 1) / 2
        let bodyDrop = lift * 5
        let barY = 4 + lift * 7

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let headY = h * 0.22 + bodyDrop
            let hipY = h * 0.58 + bodyDrop
            let footY = h * 0.92

            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - 4, y: headY - 4, width: 8, height: 8)),
                with: .color(ink),
                lineWidth: 1.8
            )

            var torso = Path()
            torso.move(to: CGPoint(x: cx, y: headY + 4))
            torso.addLine(to: CGPoint(x: cx, y: hipY))
            ctx.stroke(torso, with: .color(ink), lineWidth: 2)

            var legL = Path()
            legL.move(to: CGPoint(x: cx, y: hipY))
            legL.addLine(to: CGPoint(x: cx - 7, y: footY))
            ctx.stroke(legL, with: .color(ink), lineWidth: 2)

            var legR = Path()
            legR.move(to: CGPoint(x: cx, y: hipY))
            legR.addLine(to: CGPoint(x: cx + 7, y: footY))
            ctx.stroke(legR, with: .color(ink), lineWidth: 2)

            // Arms to bar
            let barYPos = headY - 2 - barY
            var armL = Path()
            armL.move(to: CGPoint(x: cx, y: headY + 10))
            armL.addLine(to: CGPoint(x: cx - 14, y: barYPos + 2))
            ctx.stroke(armL, with: .color(ink), lineWidth: 1.8)

            var armR = Path()
            armR.move(to: CGPoint(x: cx, y: headY + 10))
            armR.addLine(to: CGPoint(x: cx + 14, y: barYPos + 2))
            ctx.stroke(armR, with: .color(ink), lineWidth: 1.8)

            // Barbell
            var bar = Path()
            bar.move(to: CGPoint(x: cx - 18, y: barYPos))
            bar.addLine(to: CGPoint(x: cx + 18, y: barYPos))
            ctx.stroke(bar, with: .color(ink), lineWidth: 2.4)

            for side in [-1.0, 1.0] {
                let plate = CGRect(x: cx + CGFloat(side) * 17 - 3, y: barYPos - 5, width: 6, height: 10)
                ctx.fill(Path(roundedRect: plate, cornerRadius: 1), with: .color(ink.opacity(0.85)))
            }
        }
    }

    // MARK: - Longevity — beating heart

    private func longevityHeart(t: Double) -> some View {
        let beat = abs(sin(t * 4.5))
        let scale = 0.82 + beat * 0.28

        return Image(systemName: "heart.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(ink)
            .scaleEffect(scale)
    }

    // MARK: - Fat loss — scale + decreasing weight

    private func fatLossScale(t: Double) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 3)
        let base = 195
        let delta = Int((cycle / 3) * 28)
        let reading = max(base - delta, 167)

        return ZStack {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(ink.opacity(0.35))

            Text("\(reading)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .offset(y: -2)
        }
    }

    // MARK: - Athleticism — running in place

    private func athleticismRun(t: Double) -> some View {
        let stride = sin(t * 7)
        let legL = stride * 10
        let legR = -stride * 10
        let armL = -stride * 8
        let armR = stride * 8

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let headY = h * 0.18

            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - 4, y: headY, width: 8, height: 8)),
                with: .color(ink),
                lineWidth: 1.8
            )

            var torso = Path()
            torso.move(to: CGPoint(x: cx, y: headY + 8))
            torso.addLine(to: CGPoint(x: cx, y: h * 0.52))
            ctx.stroke(torso, with: .color(ink), lineWidth: 2)

            var la = Path()
            la.move(to: CGPoint(x: cx, y: headY + 12))
            la.addLine(to: CGPoint(x: cx - 10, y: headY + 12 + CGFloat(armL)))
            ctx.stroke(la, with: .color(ink), lineWidth: 1.8)

            var ra = Path()
            ra.move(to: CGPoint(x: cx, y: headY + 12))
            ra.addLine(to: CGPoint(x: cx + 10, y: headY + 12 + CGFloat(armR)))
            ctx.stroke(ra, with: .color(ink), lineWidth: 1.8)

            var ll = Path()
            ll.move(to: CGPoint(x: cx, y: h * 0.52))
            ll.addLine(to: CGPoint(x: cx - 8, y: h * 0.88 + CGFloat(legL)))
            ctx.stroke(ll, with: .color(ink), lineWidth: 2)

            var rl = Path()
            rl.move(to: CGPoint(x: cx, y: h * 0.52))
            rl.addLine(to: CGPoint(x: cx + 8, y: h * 0.88 + CGFloat(legR)))
            ctx.stroke(rl, with: .color(ink), lineWidth: 2)
        }
    }

    // MARK: - Aesthetic — flex in mirror

    private func aestheticMirrorFlex(t: Double) -> some View {
        let flex = (sin(t * 1.9) + 1) / 2
        let armAngle = 35 + flex * 40
        let rad = (180 - armAngle) * .pi / 180

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let mirrorX = w * 0.5

            var mirror = Path()
            mirror.move(to: CGPoint(x: mirrorX, y: h * 0.1))
            mirror.addLine(to: CGPoint(x: mirrorX, y: h * 0.92))
            ctx.stroke(mirror, with: .color(ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            func drawFigure(cx: CGFloat, facingRight: Bool, opacity: Double) {
                let headY = h * 0.2
                let dir: CGFloat = facingRight ? 1 : -1

                ctx.stroke(
                    Path(ellipseIn: CGRect(x: cx - 3.5, y: headY, width: 7, height: 7)),
                    with: .color(ink.opacity(opacity)),
                    lineWidth: 1.6
                )

                var torso = Path()
                torso.move(to: CGPoint(x: cx, y: headY + 7))
                torso.addLine(to: CGPoint(x: cx, y: h * 0.55))
                ctx.stroke(torso, with: .color(ink.opacity(opacity)), lineWidth: 1.8)

                let elbow = CGPoint(x: cx + dir * 10, y: headY + 14)
                let hand = CGPoint(
                    x: elbow.x + cos(rad) * 14 * dir,
                    y: elbow.y + sin(rad) * 14
                )
                var arm = Path()
                arm.move(to: CGPoint(x: cx, y: headY + 10))
                arm.addLine(to: elbow)
                arm.addLine(to: hand)
                ctx.stroke(arm, with: .color(ink.opacity(opacity)), lineWidth: 1.8)

                var leg1 = Path()
                leg1.move(to: CGPoint(x: cx, y: h * 0.55))
                leg1.addLine(to: CGPoint(x: cx - dir * 6, y: h * 0.9))
                ctx.stroke(leg1, with: .color(ink.opacity(opacity)), lineWidth: 1.8)

                var leg2 = Path()
                leg2.move(to: CGPoint(x: cx, y: h * 0.55))
                leg2.addLine(to: CGPoint(x: cx + dir * 6, y: h * 0.9))
                ctx.stroke(leg2, with: .color(ink.opacity(opacity)), lineWidth: 1.8)
            }

            drawFigure(cx: w * 0.28, facingRight: true, opacity: 1)
            drawFigure(cx: w * 0.72, facingRight: false, opacity: 0.38)
        }
    }

    // MARK: - Physical rehab — bandaid lowering onto a small injury

    private func rehabBandaid(t: Double) -> some View {
        let press = (sin(t * 2.35) + 1) / 2

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w * 0.5
            let injuryY = h * 0.58

            // Tiny “scratch” injury under where the bandaid lands
            var scratch = Path()
            scratch.move(to: CGPoint(x: cx - 4, y: injuryY + 1))
            scratch.addLine(to: CGPoint(x: cx + 1, y: injuryY - 3))
            scratch.addLine(to: CGPoint(x: cx + 5, y: injuryY))
            ctx.stroke(scratch, with: .color(Color.red.opacity(0.55)), lineWidth: 1.2)

            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 1.8, y: injuryY - 1.5, width: 3.6, height: 3.2)),
                with: .color(Color.red.opacity(0.35))
            )

            let bandW = w * 0.62
            let bandH = h * 0.22
            let hoverY = h * 0.08
            let placedY = injuryY - bandH * 0.55
            let bandY = hoverY + (placedY - hoverY) * press

            let tapeFill: Color = isSelected
                ? Color.white.opacity(0.88)
                : Color(red: 0.94, green: 0.89, blue: 0.82)

            let rect = CGRect(x: cx - bandW / 2, y: bandY, width: bandW, height: bandH)
            let bandPath = Path(roundedRect: rect, cornerRadius: bandH * 0.28)
            ctx.fill(bandPath, with: .color(tapeFill))
            ctx.stroke(bandPath, with: .color(ink.opacity(0.45)), lineWidth: 0.9)

            let padRect = CGRect(
                x: cx - bandW * 0.2,
                y: bandY + bandH * 0.2,
                width: bandW * 0.4,
                height: bandH * 0.6
            )
            ctx.fill(
                Path(roundedRect: padRect, cornerRadius: bandH * 0.15),
                with: .color(isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.92))
            )

            for dx in [-bandW * 0.14, bandW * 0.14] {
                let hole = CGRect(x: cx + dx - 1.2, y: bandY + bandH * 0.4, width: 2.4, height: 2.4)
                ctx.stroke(Path(ellipseIn: hole), with: .color(ink.opacity(0.2)), lineWidth: 0.6)
            }

            // Fingertip nudging the bandaid down when nearly placed
            if press > 0.55 {
                let tipX = cx + bandW * 0.22
                let tipY = bandY - 1 + CGFloat(1 - press) * 4
                ctx.fill(
                    Path(ellipseIn: CGRect(x: tipX - 2, y: tipY, width: 4, height: 5)),
                    with: .color(ink.opacity(0.35))
                )
            }
        }
    }
}
