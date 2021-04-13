import UIKit

public protocol ImageDataSource:class {
    func numberOfImages() -> Int
    func imageItem(at index:Int) -> ImageItem
    
    func maskedCorners(at index:Int) -> CACornerMask
    func sourceImageView(atIndex index: Int) -> UIImageView?
}

public extension ImageDataSource {
    func maskedCorners(at index:Int) -> CACornerMask { [] }
    func sourceImageView(atIndex index: Int) -> UIImageView? { nil }
}

public class ImageCarouselViewController:UIPageViewController, ImageViewerTransitionViewControllerConvertible {
    
    unowned var initialSourceView: UIImageView?
    var sourceView: UIImageView? {
        guard let vc = viewControllers?.first as? ImageViewerController else {
            return nil
        }
        return initialIndex == vc.index ? initialSourceView : nil
    }
    
    var targetView: UIImageView? {
        guard let vc = viewControllers?.first as? ImageViewerController else {
            return nil
        }
        return vc.imageView
    }
    
    func maskedCorners() -> CACornerMask {
        guard let vc = viewControllers?.first as? ImageViewerController, let imageDatasource = imageDatasource else {
            return []
        }
        
        return imageDatasource.maskedCorners(at: vc.index) 
    }
    
    weak var imageDatasource:ImageDataSource?
    let imageLoader:ImageLoader
 
    var initialIndex = 0
    
    var theme:ImageViewerTheme = .light {
        didSet {
            navItem.leftBarButtonItem?.tintColor = theme.tintColor
            backgroundView.backgroundColor = theme.color
        }
    }
    
    var options:[ImageViewerOption] = []
    
    private var onRightNavBarTapped:((Int) -> Void)?
    
    private(set) lazy var navBar:UINavigationBar = {
        let _navBar = UINavigationBar(frame: .zero)
        _navBar.isTranslucent = false
        return _navBar
    }()
    
    private(set) lazy var backgroundView:UIView = {
        let _v = UIView()
        _v.backgroundColor = theme.color
        _v.alpha = 1.0
        return _v
    }()
    private(set) lazy var statusBarBackgroundView:UIView = {
        let _v = UIView()
        _v.backgroundColor = theme.color
        _v.alpha = 1.0
        _v.frame = view.convert(UIApplication.shared.statusBarFrame, from: nil).intersection(view.bounds)
        return _v
    }()
    
    private(set) lazy var navItem:UINavigationItem = {
        let item = UINavigationItem()
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        item.titleView = label
        return item
    }()
    
    private let imageViewerPresentationDelegate = ImageViewerTransitionPresentationManager()
    
    public init(
        sourceView:UIImageView,
        imageDataSource: ImageDataSource?,
        imageLoader: ImageLoader,
        options:[ImageViewerOption] = [],
        initialIndex:Int = 0) {
        
        self.initialSourceView = sourceView
        self.initialIndex = initialIndex
        self.options = options
        self.imageDatasource = imageDataSource
        self.imageLoader = imageLoader
        let pageOptions = [UIPageViewController.OptionsKey.interPageSpacing: 20]
        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: pageOptions)
        
        transitioningDelegate = imageViewerPresentationDelegate
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addNavBar() {
        // Add Navigation Bar
        let closeBarButton = UIBarButtonItem(
            title: NSLocalizedString("Close", comment: "Close button title"),
            style: .plain,
            target: self,
            action: #selector(dismiss(_:)))
        
        navItem.leftBarButtonItem = closeBarButton
        navItem.leftBarButtonItem?.tintColor = theme.tintColor
        navBar.items = [navItem]
        navBar.insert(to: view)
    }
    
    private func addBackgroundView() {
        view.addSubview(backgroundView)
        backgroundView.bindFrameToSuperview()
        view.sendSubviewToBack(backgroundView)
    }
    
    private func applyOptions() {
        
        options.forEach {
            switch $0 {
                case .theme(let theme):
                    self.theme = theme
                case .closeIcon(let icon):
                    navItem.leftBarButtonItem?.image = icon
                case .rightNavItemTitle(let title, let onTap):
                    navItem.rightBarButtonItem = UIBarButtonItem(
                        title: title,
                        style: .plain,
                        target: self,
                        action: #selector(didTapRightNavBarItem(_:)))
                    onRightNavBarTapped = onTap
                case .rightNavItemIcon(let icon, let onTap):
                    navItem.rightBarButtonItem = UIBarButtonItem(
                        image: icon,
                        style: .plain,
                        target: self,
                        action: #selector(didTapRightNavBarItem(_:)))
                    onRightNavBarTapped = onTap
            }
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        addBackgroundView()
        addNavBar()
        view.addSubview(statusBarBackgroundView)
        applyOptions()
        
        dataSource = self
        delegate = self

        if let imageDatasource = imageDatasource {
            let initialVC = makeImageViewerController(
                initialIndex: initialIndex, 
                imageItem: imageDatasource.imageItem(at: initialIndex), 
                imageLoader: imageLoader)
            setViewControllers([initialVC], direction: .forward, animated: true)
            (navItem.titleView as? UILabel)?.attributedText = attributedText(forViewControllerTitle: initialVC.title)
            navItem.titleView?.sizeToFit()
        }
    }
    
    private func makeImageViewerController(initialIndex: Int, imageItem: ImageItem, imageLoader: ImageLoader) -> ImageViewerController {
        let initialVC:ImageViewerController = .init(
            index: initialIndex,
            imageItem: imageItem,
            imageLoader: imageLoader)
        initialVC.singleTapAction = { [weak self] in
            guard let self = self else { return }
            let currentNavAlpha = self.navBar.alpha ?? 0.0
            let shouldHide = currentNavAlpha > 0.5
            if self.navBar.isHidden && !shouldHide {
                self.navBar.isHidden = false
            }
            UIView.animate(withDuration: 0.235) { 
                self.statusBarBackgroundView.alpha = shouldHide ? 0.0 : 1.0 
                self.navBar.alpha = shouldHide ? 0.0 : 1.0 
                self.setNeedsStatusBarAppearanceUpdate()
            } completion: { (finished) in
                self.navBar.isHidden = shouldHide
            }

        }
        initialVC.updateBackgroundViewsAlpha = { [weak self] alpha in
            guard let self = self else { return }
            self.backgroundView.alpha = alpha
            if !self.navBar.isHidden { 
                self.navBar.alpha = alpha
            }
        }
        return initialVC
    }
    
    private func attributedText(forViewControllerTitle title: String?) -> NSAttributedString? {
        guard let title = title else { return nil }
        let lines = title.components(separatedBy: .newlines)
        let text = NSMutableAttributedString()
        guard let firstOriginalLine = lines.first else { return nil }
        let firstLineText = NSAttributedString(string: firstOriginalLine, attributes: 
                                                [.font: UIFont.preferredFont(forTextStyle: .body)])
        text.append(firstLineText)
        let otherLines = Array(lines.dropFirst())
        if !otherLines.isEmpty {
            let otherLinesString = NSAttributedString(string: "\n".appending(otherLines.joined(separator: " ")), 
                                                      attributes: [.font: UIFont.preferredFont(forTextStyle: .footnote),
                                                             .foregroundColor: UIColor.darkGray])
            text.append(otherLinesString)
        }
        return text
    }
    
    public override var prefersStatusBarHidden: Bool {
        navBar.alpha < 0.001
    }

    @objc
    private func dismiss(_ sender:UIBarButtonItem) {
        dismissMe(completion: nil)
    }
    
    public func dismissMe(completion: (() -> Void)? = nil) {
        sourceView?.alpha = 1.0
        UIView.animate(withDuration: 0.235, animations: {
            self.view.alpha = 0.0
        }) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
    
    deinit {
        initialSourceView?.alpha = 1.0
    }
    
    @objc
    func didTapRightNavBarItem(_ sender:UIBarButtonItem) {
        guard let onTap = onRightNavBarTapped,
            let _firstVC = viewControllers?.first as? ImageViewerController
            else { return }
        onTap(_firstVC.index)
    }
    
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        if theme == .dark {
            return .lightContent
        }
        return .default
    }
}

extension ImageCarouselViewController:UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let vc = viewController as? ImageViewerController else { return nil }
        guard let imageDatasource = imageDatasource else { return nil }
        guard vc.index > 0 else { return nil }
 
        let newIndex = vc.index - 1
        return makeImageViewerController(
            initialIndex: newIndex, 
            imageItem: imageDatasource.imageItem(at: newIndex), 
            imageLoader: vc.imageLoader)
    }
    
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        guard let vc = viewController as? ImageViewerController else { return nil }
        guard let imageDatasource = imageDatasource else { return nil }
        guard vc.index <= (imageDatasource.numberOfImages() - 2) else { return nil }
        
        let newIndex = vc.index + 1
        return makeImageViewerController(
            initialIndex: newIndex, 
            imageItem: imageDatasource.imageItem(at: newIndex), 
            imageLoader: vc.imageLoader)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let currentVC = pageViewController.viewControllers?.first as? ImageViewerController else { return }
        
        // Make previous source image view visible
        initialSourceView?.alpha = 1.0
        
        // Update views and make new source image view hidden
        initialSourceView = imageDatasource?.sourceImageView(atIndex: currentVC.index)
        initialSourceView?.alpha = 0.0
        initialIndex = currentVC.index
        
        (navItem.titleView as? UILabel)?.attributedText = attributedText(forViewControllerTitle: currentVC.title)
        navItem.titleView?.sizeToFit()
    }
}
