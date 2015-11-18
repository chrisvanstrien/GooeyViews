import Darwin
import QuartzCore

class MatrixFactory {
    class func orthographic(left left: Float, right: Float, top: Float, bottom: Float, near: Float, far: Float) -> CATransform3D {
        let m00 = 2 / (right-left)
        let m11 = 2 / (top-bottom)
        let m22 = -2 / (far-near)
        let m03 = -(right+left) / (right-left)
        let m13 = -(top+bottom) / (top-bottom)
        let m23 = (far+near) / (far-near)
        
        let orthographic: [Float] = [
            m00, 0,   0,   0,
            0,   m11, 0,   0,
            0,   0,   m22, 0,
            m03, m13, m23, 1]
        
        let matrix = MatrixFactory.matrix(orthographic)
        
        return matrix
    }
    
    class func perspective(fov fov: Float, aspect: Float, near: Float, far: Float) -> CATransform3D {
        let depth = far - near
        let invDepth = 1 / depth
        
        let m11 = 1 / tan(0.5 * fov)
        let m00 = m11 / aspect
        let m22 = far * invDepth
        let m32 = -far * near * invDepth
        
        let perspective: [Float] = [
            m00, 0,   0,   0,
            0,   m11, 0,   0,
            0,   0,   m22, 1,
            0,   0,   m32, 0]
        
        let matrix = MatrixFactory.matrix(perspective)
        
        return matrix
    }
    
    class func matrix(array: [Float]) -> CATransform3D {
        let a = array.map { CGFloat($0) }
        
        let matrix = CATransform3D(
            m11: a[0],  m12: a[1],  m13: a[2],  m14: a[3],
            m21: a[4],  m22: a[5],  m23: a[6],  m24: a[7],
            m31: a[8],  m32: a[9],  m33: a[10], m34: a[11],
            m41: a[12], m42: a[13], m43: a[14], m44: a[15])
        
        return matrix
    }
    
    class func array(transform: CATransform3D) -> [Float] {
        let t = transform
        
        let array = [
            t.m11, t.m12, t.m13, t.m14,
            t.m21, t.m22, t.m23, t.m24,
            t.m31, t.m32, t.m33, t.m34,
            t.m41, t.m42, t.m43, t.m44
        ]
        
        let floatArray = array.map { Float($0) }
        
        return floatArray
    }
    
    class func transpose(transform: CATransform3D) -> CATransform3D {
        let t = transform
        
        let transpose = CATransform3D(
            m11: t.m11, m12: t.m21, m13: t.m31, m14: t.m41,
            m21: t.m12, m22: t.m22, m23: t.m32, m24: t.m42,
            m31: t.m13, m32: t.m23, m33: t.m33, m34: t.m43,
            m41: t.m14, m42: t.m24, m43: t.m34, m44: t.m44)
        
        return transpose
    }
}
