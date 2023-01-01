import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        
        return Coordinator( self )
    }

    func makeUIView( context: UIViewRepresentableContext<MetalView> ) -> MTKView {
    
        let mtkView = MTKView()

        mtkView.delegate                 = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.device                   = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly          = true
        mtkView.clearColor               = MTLClearColor( red: 0, green: 0, blue: 0, alpha: 0 )
        mtkView.drawableSize             = mtkView.frame.size
        mtkView.enableSetNeedsDisplay    = false
        mtkView.depthStencilPixelFormat  = .depth32Float

        context.coordinator.createPipelineState( colorPixelFormat: mtkView.colorPixelFormat )
        context.coordinator.mtkView( mtkView, drawableSizeWillChange: mtkView.bounds.size )

        return mtkView
    }
    
    func updateUIView( _ uiView: MTKView, context: UIViewRepresentableContext<MetalView> ) {

    }

    struct Uniform {
        var color : SIMD3<Float>
    }

    class Coordinator : NSObject, MTKViewDelegate {

        let device            : MTLDevice
        let commandQueue      : MTLCommandQueue
        let vertexBuffer      : MTLBuffer
        let uniformBuffer     : MTLBuffer
        let depthStencilState : MTLDepthStencilState
        var pipelineState     : MTLRenderPipelineState?
        var uniform           : Uniform
        var count             : Int


        init( _ parent: MetalView ) {
        
            device = MTLCreateSystemDefaultDevice()!

            commandQueue = device.makeCommandQueue()!

            let vertices : [SIMD4<Float>] = [ SIMD4<Float>( -0.5, -0.5, 0.0, 1.0 ),
                                              SIMD4<Float>(  0.5, -0.5, 0.0, 1.0 ),
                                              SIMD4<Float>(  0.0,  0.5, 0.0, 1.0 ) ]
                                              
            vertexBuffer = device.makeBuffer(
                bytes   : vertices,
                length  : MemoryLayout<SIMD4<Float>>.stride * vertices.count,
                options : .storageModeShared
            )!

            uniformBuffer = device.makeBuffer(
                length  : MemoryLayout<SIMD3<Float>>.stride,
                options : .storageModeShared
            )!

            let desc = MTLDepthStencilDescriptor()
            desc.depthCompareFunction = .always
            desc.isDepthWriteEnabled = false
            depthStencilState = device.makeDepthStencilState( descriptor: desc )!
            uniform = Uniform( color : SIMD3<Float>(0,0,0))

            count = 0

            super.init()
        }

        func mtkView( _ view: MTKView, drawableSizeWillChange size: CGSize ) {
        }

        static func updateUniformBuffer( buffer : MTLBuffer, uniform: [Uniform] ) {

            // The following pointer assignment works all with -O, -Onone, and -Osize.

//            let rawP      = buffer.contents()
//            let typedP    = rawP.bindMemory( to: Uniform.self, capacity: MemoryLayout<Uniform>.stride )
//            let bufferedP = UnsafeMutableBufferPointer( start: typedP, count: 1 )
//            for u in uniform {
//                bufferedP[0] = u
//            }

            // The following copyMemory() works only with -Onone and -Osize, but not with -O.
            buffer.contents().copyMemory( from: uniform, byteCount: MemoryLayout<SIMD3<Float>>.stride )
        }

        func draw( in view: MTKView ) {

            count = (count + 1) % 256
            let val   = Float(count)/256.0
            uniform = Uniform( color : SIMD3<Float>( val, val, val ) )
            Self.updateUniformBuffer( buffer: uniformBuffer, uniform: [uniform] )

            guard
                let descriptor    = view.currentRenderPassDescriptor,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let encoder = commandBuffer.makeRenderCommandEncoder( descriptor: descriptor )
            else {
                return
            }
            encoder.setRenderPipelineState( pipelineState! )
            encoder.setDepthStencilState( depthStencilState )
            encoder.setVertexBuffer( vertexBuffer, offset: 0, index: 0 )
            encoder.setFragmentBuffer( uniformBuffer, offset: 0, index: 0 )
            encoder.drawPrimitives( type: .triangle, vertexStart: 0, vertexCount: 3 )
            encoder.endEncoding()

            guard let drawable = view.currentDrawable
            else {
                return
            }
            commandBuffer.present( drawable )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    
        func createPipelineState( colorPixelFormat : MTLPixelFormat ) {
    
            let library = device.makeDefaultLibrary()

            let descriptor = MTLRenderPipelineDescriptor()

            descriptor.vertexFunction   = library!.makeFunction( name: "vert" )
            descriptor.fragmentFunction = library!.makeFunction( name: "frag" )

            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format      = .float4
            vertexDescriptor.attributes[0].offset      = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.layouts[0].stride         = MemoryLayout<SIMD4<Float>>.stride
            vertexDescriptor.layouts[0].stepFunction   = .perVertex

            descriptor.vertexDescriptor = vertexDescriptor
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = false
            descriptor.depthAttachmentPixelFormat  = .depth32Float

            do {
                pipelineState = try device.makeRenderPipelineState( descriptor: descriptor )

            } catch let error {

                fatalError( error.localizedDescription )
            }
        }
    }
}
