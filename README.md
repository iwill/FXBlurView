Purpose
--------------

FXBlurView is a UIView subclass that replicates the iOS 7 realtime background blur effect, but works on iOS 5 and above. It is designed to be as fast and as simple to use as possible. FXBlurView offers two modes of operation: static, where the view is rendered only once when it is added to a superview (though it can be updated by calling setNeedsDisplay) or dynamic, where it will automatically redraw itself on a background thread as often as possible.


Supported iOS & SDK Versions
-----------------------------

* Supported build target - iOS 7.0 (Xcode 5.0, Apple LLVM compiler 5.0)
* Earliest supported deployment target - iOS 5.0
* Earliest compatible deployment target - iOS 4.3

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

As of version 1.3, FXBlurView requires ARC. If you wish to use FXBlurView in a non-ARC project, just add the -fobjc-arc compiler flag to the FXBlurView.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click FXBlurView.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in FXBlurView.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including FXBlurView.m) are checked.


Installation
---------------

To use FXBlurView, just drag the class files into your project and add the Accelerate framework. You can create FXBlurView instances programatically, or create them in Interface Builder by dragging an ordinary UIView into your view and setting its class to FXBlurView.

If you are using Interface Builder, to set the custom properties of FXBlurView (ones that are not supported by regular UIViews) either create an IBOutlet for your view and set the properties in code, or use the User Defined Runtime Attributes feature in Interface Builder (introduced in Xcode 4.2 for iOS 5+).


UIImage extensions
--------------------

FXBlurView extends UIImage with the following method in UIImage+ImageEffects.h:

    - (UIImage *)applyBlurWithRadius:(CGFloat)radius
                           tintColor:(UIColor *)tintColor
               saturationDeltaFactor:(CGFloat)saturationDeltaFactor;

This method applies a blur effect and returns the resultant blurred image without modifying the original. See UIImage+ImageEffects.h for more.


FXBlurView properties
----------------

    @property (nonatomic, getter = isBlurEnabled) BOOL blurEnabled;

This property toggles blurring on and off for an individual FXBlurView instance. Blurring is enabled by default. Note that if you disable blurring using the `+setBlurEnabled` method then that will override this setting.

	@property (nonatomic, getter = isDynamic) BOOL dynamic;

This property controls whether the FXBlurView updates dynamically, or only once when the view is added to its superview. Defaults to YES. Note that is dynamic is set to NO, you can still force the view to update by calling setNeedsDisplay. Dynamic blurring is extremely cpu-intensive, so you should always disable dyanmic views immediately prior to performing an animation to avoid stuttering. However, if you have mutliple FXBlurViews on screen then it is simpler to disable updates using the `setUpdatesDisabled` method rather than setting the `dynamic` property to NO.

    @property (nonatomic, assign) NSTimeInterval updateInterval;

This controls the interval (in seconds) between successive updates when the FXBlurView is operating in dynamic mode. This defaults to zero, which means that the FXBlurView will update as fast as possible. This yields the best frame rate, but is also extremely CPU intensive and may cause the rest of your app's performance to degrade, especially on older devices. To alleviate this, try increasing the `updateInterval` value.

    @property (nonatomic, assign) CGFloat blurRadius;	

This property controls the radius of the blur effect (in points). Defaults to a 40 point radius, which is similar to the iOS 7 blur effect.

    @property (nonatomic, strong) UIColor *tintColor;

This in an optional tint color to be applied to the FXBlurView. The RGB components of the color will be blended with the blurred image, resulting in a gentle tint. To vary the intensity of the tint effect, use brighter or darker colors. The alpha component of the tintColor is NOT ignored. If you do not wish to apply a tint, set this value to nil or [UIColor clearColor]. Note that if you are using Xcode 5 or above, FXBlurViews created in Interface Builder will have a blue tint by default.

    @property (nonatomic, assign) CGFloat saturationDeltaFactor;

See UIImage+ImageEffects.h for more.


FXBlurView methods
-----------------------

    + (void)setBlurEnabled:(BOOL)blurEnabled;

This method can be used to globally enable/disable the blur effect on all FXBlurView instances. This is useful for testing, or if you wish to disable blurring on iPhone 4 and below (for consistency with iOS7 blur view behavior). By default blurring is enabled.

    + (void)setUpdatesEnabled;
    + (void)setUpdatesDisabled;

These methods can be used to enable and disable updates for all dynamic FXBlurView instances with a single command. Useful for disabling updates immediately before performing an animation so that the FXBlurView updates don't cuase the animation to stutter. Calls can be nested, but ensure that the enabled/disabled calls are balanced, or the updates will be left permantently enabled or disabled.

    - (void)setNeedsDisplay;

Inherited from UIView, this method can be used to trigger a (synchronous) update of the view. Useful when `dynamic = NO`. 

    - (void)setupLightEffect;
    - (void)setupExtraLightEffect;
    - (void)setupDarkEffect;

iOS 7 blur effects from Apple SampleCodes. See UIImage+ImageEffects.h for more.

    - (void)setupLightEffectWithColor:(UIColor *)tintColor;
    - (void)setupExtraLightEffectWithColor:(UIColor *)tintColor;
    - (void)setupDarkEffectWithColor:(UIColor *)tintColor;

iOS 7 blur effects with custom tint color like Apple SampleCodes. See UIImage+ImageEffects.h for more.

    - (void)setupTintEffectWithColor:(UIColor *)tintColor;

iOS 7 blur effects from Apple SampleCodes. See UIImage+ImageEffects.h for more.


FAQ
----------------

    Q. Why are my views all blue-tinted on iOS 7?
    A. FXBlurView uses the `UIView` `tintColor` property, which does not exist on iOS 6 and below, but defaults to blue on iOS 7. Just set this property to `[UIColor clearColor]` to disable the tint. To retain iOS 6 compatibility, you can either set this using code, or by using the User Defined Runtime Attributes feature of Interface Builder, which will override the standard `tintColor` value (see the example project nibs for how to do this).
    
    Q. FXBlurView makes my whole app run slowly on [old device], what can I do
    A. To improve performance, try increasing the `updatePeriod` property, disabling `dynamic` unless you really need it. If all else fails, set `blurEnabled` to NO on older devices.
    
    Q. My SpriteKit/OpenGL/Video/3D transformed content isn't showing up properly when placed underneath an FXBlurView, why not?
    A. This is a limitation of a the `CALayer` `renderInContext:` method used to capture the superview contents. There is no workaround for this on iOS 6 and earlier. On iOS 7 you can make use of the `UIView` `drawViewHierarchyInRect:afterScreenUpdates:` method to capture an view and apply the blur effect yourself, but this it too slow for realtime use, so FXBlurView does not use this method by default.
    
    Q. FXBlurView is not capturing some ordinary view content that is behind it, why not?
    A. FXBlurView only captures the contents of its immediate superview. If the superview is transparent or partially transparent, content shown behind it will not be captured.

