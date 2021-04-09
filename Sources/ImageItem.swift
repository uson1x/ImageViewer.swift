import UIKit

public enum ImageItem {
    case image(UIImage?, author: String?, date: Date?)
    case url(URL, placeholder: UIImage?, author: String?, date: Date?)
}
