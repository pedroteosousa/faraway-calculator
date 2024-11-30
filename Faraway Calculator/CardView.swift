//
//  CardView.swift
//  Faraway Calculator
//
//  Created by Pedro Sousa on 09/11/24.
//

import SwiftUI

extension UIImage {
    public func withRoundedCorners(radius: CGFloat? = nil) -> UIImage? {
        let maxRadius = min(size.width, size.height) / 2
        let cornerRadius: CGFloat
        if let radius = radius, radius > 0 && radius <= maxRadius {
            cornerRadius = radius
        } else {
            cornerRadius = maxRadius
        }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let rect = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        draw(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

struct RegionCard: View {
    let croppedImage: Image
    
    static var image: UIImage? = nil

    init?(region: Int) {
        if RegionCard.image == nil {
            guard let data = try? Data(contentsOf: Bundle.main.url(forResource: "regions", withExtension: "png")!) else {
                return nil
            }
            RegionCard.image = UIImage(data: data)!
        }
        
        let width = RegionCard.image!.size.width / 10
        let height = RegionCard.image!.size.height / 8
        
        var pos = region
        if region == 0 {
            pos = CardsInfo.shared.regions.count
        }
        
        let cgImage = RegionCard.image!.cgImage!.cropping(to: CGRect(x: CGFloat(pos % 10) * width, y: CGFloat(Int(pos / 10)) * height, width: width, height: height))
        let roundedImage = UIImage(cgImage: cgImage!).withRoundedCorners(radius: 20)
        let roundedCGImage = roundedImage?.cgImage
        self.croppedImage = Image(decorative: roundedCGImage!, scale: RegionCard.image!.scale, orientation: .up)
    }

    var body: some View {
        croppedImage
            .resizable()
            .scaledToFit()
    }
}

struct SanctuaryCard: View {
    let croppedImage: Image
    
    static var image: UIImage? = nil

    init?(sanctuary: Int) {
        if SanctuaryCard.image == nil {
            guard let data = try? Data(contentsOf: Bundle.main.url(forResource: "sanctuaries", withExtension: "png")!) else {
                return nil
            }
            SanctuaryCard.image = UIImage(data: data)!
        }
        
        let width = SanctuaryCard.image!.size.width / 10
        let height = SanctuaryCard.image!.size.height / 6
        
        let cgImage = SanctuaryCard.image!.cgImage!.cropping(to: CGRect(x: CGFloat(sanctuary % 10) * width, y: CGFloat(Int(sanctuary / 10)) * height, width: width, height: height))
        let roundedImage = UIImage(cgImage: cgImage!).withRoundedCorners(radius: 20)
        let roundedCGImage = roundedImage?.cgImage
        self.croppedImage = Image(decorative: roundedCGImage!, scale: SanctuaryCard.image!.scale, orientation: .up)
    }

    var body: some View {
        croppedImage
            .resizable()
            .scaledToFit()
    }
}

struct CardView: View {
    let id: Int
    let type: CardType
    let score: Int?
    
    var body: some View {
        ZStack {
            if type == .region {
                RegionCard(region: id)
            } else {
                SanctuaryCard(sanctuary: id)
            }
            if score != nil {
                Text("\(score!)")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .font(.system(size: 20))
                    .shadow(color: .black, radius: 1)
                    .padding()
                    .background(Color(UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)))
                    .border(.white, width: 2)
            }
        }
    }
}
