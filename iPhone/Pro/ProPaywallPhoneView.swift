import SwiftUI
import SceneKit
import UIKit

// 3D iPhone model for the Pro paywall carousel.
// Mirrors the SceneKit pattern from the Disposable project:
// loads iPhone_17_Pro.usdz, applies a UIImage screen texture,
// and responds to SwiftUI animation by rotating the phone node.
struct ProPaywallPhoneView: UIViewRepresentable, Animatable {
    var angle: Double          // Y-axis rotation in degrees
    let screenImage: UIImage?

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.autoenablesDefaultLighting = false
        v.allowsCameraControl = false
        v.isUserInteractionEnabled = false
        v.scene = context.coordinator.scene
        context.coordinator.build(screenImage: screenImage, initialAngle: angle)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(angle: angle, screenImage: screenImage)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator {
        let scene = SCNScene()
        private let phoneNode = SCNNode()
        private var displayMaterial: SCNMaterial?
        private var fallbackMaterial: SCNMaterial?
        private var lastImageID: ObjectIdentifier?

        init() {
            scene.rootNode.addChildNode(phoneNode)
            configureCamera()
            configureLights()
        }

        func build(screenImage: UIImage?, initialAngle: Double) {
            phoneNode.childNodes.forEach { $0.removeFromParentNode() }
            displayMaterial = nil
            fallbackMaterial = nil
            lastImageID = nil
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            phoneNode.eulerAngles.y = Float(initialAngle * .pi / 180)
            SCNTransaction.commit()
            loadPhone(screenImage: screenImage)
        }

        func update(angle: Double, screenImage: UIImage?) {
            // Screen texture swap
            let newID = screenImage.map { ObjectIdentifier($0) }
            if newID != lastImageID {
                lastImageID = newID
                displayMaterial?.diffuse.contents = screenImage ?? UIColor.black
                displayMaterial?.emission.contents = screenImage ?? UIColor.black
                fallbackMaterial?.diffuse.contents = screenImage ?? UIColor.black
                fallbackMaterial?.emission.contents = screenImage ?? UIColor.black
            }
            // Angle — SwiftUI drives interpolation each frame via Animatable
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            phoneNode.eulerAngles.y = Float(angle * .pi / 180)
            SCNTransaction.commit()
        }

        // MARK: - Model loading

        private func loadPhone(screenImage: UIImage?) {
            guard let url = Bundle.main.url(forResource: "iPhone_17_Pro", withExtension: "usdz"),
                  let modelScene = try? SCNScene(url: url) else {
                buildFallback(screenImage: screenImage)
                return
            }
            let wrapper = SCNNode()
            for child in modelScene.rootNode.childNodes {
                wrapper.addChildNode(child.clone())
            }
            normalizeModel(wrapper)
            applyScreenTexture(to: wrapper, image: screenImage)
            wrapper.eulerAngles.y = 0
            phoneNode.addChildNode(wrapper)
        }

        private func normalizeModel(_ node: SCNNode) {
            let b = node.boundingBox
            let largest = Swift.max(b.max.x - b.min.x, b.max.y - b.min.y, b.max.z - b.min.z)
            guard largest > 0 else { return }
            let s = Float(3.1) / largest
            let c = SCNVector3((b.min.x + b.max.x) / 2, (b.min.y + b.max.y) / 2, (b.min.z + b.max.z) / 2)
            node.scale    = SCNVector3(s, s, s)
            node.position = SCNVector3(-c.x * s, -c.y * s, -c.z * s)
        }

        private func applyScreenTexture(to root: SCNNode, image: UIImage?) {
            func visit(_ node: SCNNode) {
                if let geo = node.geometry,
                   geo.materials.contains(where: { $0.name == "Display" }) {
                    let b = node.boundingBox
                    let w = CGFloat((b.max.x - b.min.x) * 0.985)
                    let h = CGFloat((b.max.y - b.min.y) * 0.985)
                    let plane = SCNPlane(width: w, height: h)
                    let mat = SCNMaterial()
                    let content: Any = image ?? UIColor.black
                    mat.diffuse.contents  = content
                    mat.emission.contents = content
                    mat.diffuse.wrapS = .clamp
                    mat.diffuse.wrapT = .clamp
                    mat.lightingModel       = .constant
                    mat.blendMode           = .alpha
                    mat.writesToDepthBuffer = false
                    mat.readsFromDepthBuffer = false
                    plane.materials = [mat]
                    displayMaterial = mat
                    let dn = SCNNode(geometry: plane)
                    dn.position = SCNVector3(
                        (b.min.x + b.max.x) / 2,
                        (b.min.y + b.max.y) / 2,
                        b.max.z + 0.0001
                    )
                    dn.renderingOrder = 80
                    node.addChildNode(dn)
                    geo.materials.forEach {
                        if $0.name == "Display" {
                            $0.diffuse.contents  = UIColor.black
                            $0.emission.contents = UIColor.black
                        }
                    }
                    return
                }
                node.childNodes.forEach { visit($0) }
            }
            visit(root)
        }

        private func buildFallback(screenImage: UIImage?) {
            let body = SCNBox(width: 1.55, height: 3.05, length: 0.26, chamferRadius: 0.18)
            body.materials = [simpleMat(UIColor(white: 0.1, alpha: 1), metalness: 0.18)]
            phoneNode.addChildNode(SCNNode(geometry: body))

            let screen = SCNBox(width: 1.38, height: 2.83, length: 0.025, chamferRadius: 0.14)
            let mat = simpleMat(.black)
            mat.diffuse.contents  = screenImage
            mat.emission.contents = screenImage
            mat.lightingModel = .constant
            fallbackMaterial = mat
            screen.materials = [mat]
            let sn = SCNNode(geometry: screen)
            sn.position.z = 0.155
            phoneNode.addChildNode(sn)
        }

        private func simpleMat(_ color: UIColor, metalness: CGFloat = 0) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents   = color
            m.roughness.contents = 0.6
            m.metalness.contents = metalness
            return m
        }

        // MARK: - Camera & Lights

        private func configureCamera() {
            let cam = SCNCamera()
            cam.fieldOfView = 36
            let n = SCNNode(); n.camera = cam
            n.position = SCNVector3(0, 0, 6.2)
            scene.rootNode.addChildNode(n)
        }

        private func configureLights() {
            func node(light: SCNLight, pos: SCNVector3 = .init(), angles: SCNVector3 = .init()) -> SCNNode {
                let n = SCNNode(); n.light = light
                n.position = pos; n.eulerAngles = angles
                return n
            }

            let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 250
            ambient.color = UIColor(white: 0.9, alpha: 1)
            scene.rootNode.addChildNode(node(light: ambient))

            let key = SCNLight(); key.type = .directional; key.intensity = 980
            key.temperature = 6000
            scene.rootNode.addChildNode(node(light: key, angles: SCNVector3(-0.55, -0.42, -0.2)))

            let fill = SCNLight(); fill.type = .omni; fill.intensity = 430
            scene.rootNode.addChildNode(node(light: fill, pos: SCNVector3(-2.1, 1.2, 3.6)))

            let rim = SCNLight(); rim.type = .spot; rim.intensity = 760
            rim.spotInnerAngle = 18; rim.spotOuterAngle = 54
            scene.rootNode.addChildNode(node(light: rim,
                                             pos: SCNVector3(2.2, 1.8, -2.6),
                                             angles: SCNVector3(-0.25, 2.45, 0)))
        }
    }
}
