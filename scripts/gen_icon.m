/*
 * gen_icon.m
 * Generates AppIcon.icns for Dilution Cryofree Simulator using
 * CoreGraphics – no .xcassets needed.
 *
 * Compile & run via build.sh (added step), or manually:
 *   clang -framework Cocoa -framework CoreGraphics -o /tmp/gen_icon gen_icon.m && /tmp/gen_icon
 */

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

// ── Drawing ──────────────────────────────────────────────────────────────────

static void drawCryoIcon(CGContextRef ctx, CGFloat size) {
    CGFloat cx = size * 0.5, cy = size * 0.5, r = size * 0.5;
    CGFloat pad = size * 0.02;

    // ── Background: deep space radial gradient ───────────────────────────────
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    CGFloat bgColors[] = {
        0.08, 0.10, 0.20, 1.0,   // inner: deep navy
        0.03, 0.03, 0.07, 1.0,   // outer: near-black
    };
    CGFloat bgLocs[] = { 0.0, 1.0 };
    CGGradientRef bgGrad = CGGradientCreateWithColorComponents(cs, bgColors, bgLocs, 2);

    // Clip to rounded disc
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, CGRectMake(pad, pad, size - 2*pad, size - 2*pad));
    CGContextClip(ctx);

    CGContextDrawRadialGradient(ctx, bgGrad,
        CGPointMake(cx, cy), 0,
        CGPointMake(cx, cy), r,
        kCGGradientDrawsAfterEndLocation);

    CGGradientRelease(bgGrad);

    // ── 50 K shield ring (warm brass) ────────────────────────────────────────
    CGContextSetLineWidth(ctx, size * 0.022);
    CGContextSetRGBStrokeColor(ctx, 0.65, 0.52, 0.15, 0.55);
    CGContextAddEllipseInRect(ctx, CGRectMake(cx - r*0.65, cy - r*0.65, r*1.30, r*1.30));
    CGContextStrokePath(ctx);

    // ── 4 K shield ring (blue-steel) ─────────────────────────────────────────
    CGContextSetLineWidth(ctx, size * 0.018);
    CGContextSetRGBStrokeColor(ctx, 0.28, 0.52, 0.72, 0.55);
    CGContextAddEllipseInRect(ctx, CGRectMake(cx - r*0.84, cy - r*0.84, r*1.68, r*1.68));
    CGContextStrokePath(ctx);

    // ── OVC cylinder body ────────────────────────────────────────────────────
    CGFloat ovcW = size * 0.38, ovcH = size * 0.72;
    CGFloat ovcX = cx - ovcW * 0.5, ovcY = cy - ovcH * 0.52;

    // Subtle fill
    CGContextSetRGBFillColor(ctx, 0.22, 0.26, 0.33, 0.18);
    CGContextFillRect(ctx, CGRectMake(ovcX, ovcY, ovcW, ovcH));

    // Left & right edge glows
    CGFloat edgeColors[] = {
        0.45, 0.55, 0.70, 0.55,
        0.45, 0.55, 0.70, 0.00,
    };
    CGFloat edgeLocs[] = { 0.0, 1.0 };

    // Left edge
    CGGradientRef edgeGrad = CGGradientCreateWithColorComponents(cs, edgeColors, edgeLocs, 2);
    CGContextDrawLinearGradient(ctx, edgeGrad,
        CGPointMake(ovcX, cy), CGPointMake(ovcX + size*0.06, cy),
        0);
    // Right edge
    CGContextDrawLinearGradient(ctx, edgeGrad,
        CGPointMake(ovcX + ovcW, cy), CGPointMake(ovcX + ovcW - size*0.06, cy),
        0);
    CGGradientRelease(edgeGrad);

    // ── Flanges ───────────────────────────────────────────────────────────────
    // Helper: draw a horizontal flange band
    void (^flange)(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) =
        ^(CGFloat fy, CGFloat fh, CGFloat fw, CGFloat rr, CGFloat gg, CGFloat bb, CGFloat aa, CGFloat glow) {
        CGFloat fx = cx - fw * 0.5;
        // fill
        CGContextSetRGBFillColor(ctx, rr, gg, bb, aa);
        CGFloat rad = fh * 0.35;
        CGContextBeginPath(ctx);
        CGContextMoveToPoint   (ctx, fx + rad, fy);
        CGContextAddLineToPoint(ctx, fx + fw - rad, fy);
        CGContextAddArcToPoint (ctx, fx + fw, fy, fx + fw, fy + rad, rad);
        CGContextAddLineToPoint(ctx, fx + fw, fy + fh - rad);
        CGContextAddArcToPoint (ctx, fx + fw, fy + fh, fx + fw - rad, fy + fh, rad);
        CGContextAddLineToPoint(ctx, fx + rad, fy + fh);
        CGContextAddArcToPoint (ctx, fx, fy + fh, fx, fy + fh - rad, rad);
        CGContextAddLineToPoint(ctx, fx, fy + rad);
        CGContextAddArcToPoint (ctx, fx, fy, fx + rad, fy, rad);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        // top edge glow
        CGContextSetRGBStrokeColor(ctx, rr + glow, gg + glow, bb + glow, aa * 0.8);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddRect(ctx, CGRectMake(fx, fy, fw, 1.5));
        CGContextStrokePath(ctx);
    };

    // 4 K top plate
    flange(cy - r*0.60, size*0.048, size*0.60,
           0.55, 0.70, 0.88, 0.85, 0.15);
    // Still flange (gold)
    flange(cy + r*0.12, size*0.052, size*0.50,
           0.88, 0.72, 0.18, 0.88, 0.12);
    // Cold plate flange (ice blue)
    flange(cy + r*0.30, size*0.044, size*0.42,
           0.55, 0.82, 1.00, 0.82, 0.18);

    // ── Pulse tube cold head (right side) ─────────────────────────────────────
    CGFloat ptX = cx + r*0.52 - size*0.045;
    CGFloat ptY = cy - r*0.60;
    CGFloat ptH = r*0.52;
    CGFloat ptW = size*0.090;

    CGContextSetRGBFillColor(ctx, 0.50, 0.53, 0.58, 0.75);
    CGContextFillRect(ctx, CGRectMake(ptX, ptY, ptW, ptH));

    // Stage 1 / 2 separators on PT
    CGContextSetRGBStrokeColor(ctx, 0.70, 0.72, 0.76, 0.90);
    CGContextSetLineWidth(ctx, size*0.010);
    CGContextMoveToPoint(ctx, ptX, ptY + ptH * 0.42);
    CGContextAddLineToPoint(ctx, ptX + ptW, ptY + ptH * 0.42);
    CGContextStrokePath(ctx);

    // ── Circulating He pumping line (centre tube) ─────────────────────────────
    CGFloat tubeX = cx - size*0.012;
    CGFloat tubeTop = cy - r*0.55;
    CGFloat tubeBot = cy + r*0.46;
    CGFloat tubeW = size*0.024;

    // Tube body
    CGContextSetRGBFillColor(ctx, 0.25, 0.28, 0.32, 0.65);
    CGContextFillRect(ctx, CGRectMake(tubeX, tubeTop, tubeW, tubeBot - tubeTop));

    // ³He flow: cyan dashed glow inside tube
    CGContextSetLineWidth(ctx, size * 0.012);
    CGFloat dashLen = size * 0.045, gapLen = size * 0.030;
    CGFloat dashes[] = { dashLen, gapLen };
    CGContextSetLineDash(ctx, 0, dashes, 2);
    CGContextSetRGBStrokeColor(ctx, 0.18, 0.92, 1.00, 0.80);
    CGContextMoveToPoint(ctx, cx, tubeTop + dashLen);
    CGContextAddLineToPoint(ctx, cx, tubeBot - dashLen);
    CGContextStrokePath(ctx);
    CGContextSetLineDash(ctx, 0, NULL, 0); // reset dash

    // ── Mixing chamber (sphere at bottom) ─────────────────────────────────────
    CGFloat mcR  = r * 0.20;
    CGFloat mcCY = cy + r * 0.50;

    // Gradient fill: quantum violet → cryo-cyan
    CGFloat mcColors[] = {
        0.55, 0.22, 1.00, 1.0,   // violet centre
        0.12, 0.78, 1.00, 0.95,  // cyan edge
    };
    CGFloat mcLocs[] = { 0.0, 1.0 };
    CGGradientRef mcGrad = CGGradientCreateWithColorComponents(cs, mcColors, mcLocs, 2);

    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, CGRectMake(cx - mcR, mcCY - mcR, mcR*2, mcR*2));
    CGContextClip(ctx);
    CGContextDrawRadialGradient(ctx, mcGrad,
        CGPointMake(cx - mcR*0.25, mcCY - mcR*0.30), 0,
        CGPointMake(cx, mcCY), mcR,
        kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(mcGrad);

    // Specular highlight
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.25);
    CGContextAddEllipseInRect(ctx,
        CGRectMake(cx - mcR*0.62, mcCY - mcR*0.72, mcR*0.65, mcR*0.45));
    CGContextFillPath(ctx);

    CGContextRestoreGState(ctx);

    // Outer rim on MC
    CGContextSetRGBStrokeColor(ctx, 0.18, 0.92, 1.00, 0.70);
    CGContextSetLineWidth(ctx, size * 0.010);
    CGContextAddEllipseInRect(ctx, CGRectMake(cx - mcR, mcCY - mcR, mcR*2, mcR*2));
    CGContextStrokePath(ctx);

    // ── Temperature label dots (5 quantum snowflakes) ─────────────────────────
    struct { CGFloat ox, oy; } dots[] = {
        { -0.68, -0.20 }, { 0.68, -0.20 },
        {  0.00, -0.82 }, { -0.48, 0.68 }, { 0.48, 0.68 }
    };
    for (int d = 0; d < 5; d++) {
        CGFloat dx = cx + dots[d].ox * r * 0.82;
        CGFloat dy = cy + dots[d].oy * r * 0.82;
        CGFloat dr = size * 0.022;
        CGContextSetRGBFillColor(ctx, 0.18, 0.92, 1.00, 0.45);
        CGContextAddEllipseInRect(ctx, CGRectMake(dx - dr, dy - dr, dr*2, dr*2));
        CGContextFillPath(ctx);
    }

    // ── Golden outer rim ──────────────────────────────────────────────────────
    CGContextSetLineWidth(ctx, size * 0.025);
    CGContextSetRGBStrokeColor(ctx, 1.00, 0.80, 0.20, 0.75);
    CGContextAddEllipseInRect(ctx, CGRectMake(pad + size*0.008, pad + size*0.008,
                                               size - 2*(pad + size*0.008),
                                               size - 2*(pad + size*0.008)));
    CGContextStrokePath(ctx);

    // ── Subtle inner shine at top ─────────────────────────────────────────────
    CGFloat shineColors[] = {
        1.0, 1.0, 1.0, 0.12,
        1.0, 1.0, 1.0, 0.00,
    };
    CGFloat shineLocs[] = { 0.0, 1.0 };
    CGGradientRef shineGrad = CGGradientCreateWithColorComponents(cs, shineColors, shineLocs, 2);
    CGContextDrawLinearGradient(ctx, shineGrad,
        CGPointMake(cx, cy - r), CGPointMake(cx, cy), 0);
    CGGradientRelease(shineGrad);

    CGContextRestoreGState(ctx); // restore disc clip

    CGColorSpaceRelease(cs);
}

// ── PNG helper via NSBitmapImageRep ──────────────────────────────────────────

static NSData* renderPNG(NSInteger size) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
        pixelsWide:size pixelsHigh:size
        bitsPerSample:8 samplesPerPixel:4
        hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace
        bitmapFormat:0
        bytesPerRow:0 bitsPerPixel:0];

    rep.size = NSMakeSize(size, size);

    NSGraphicsContext *nsCtx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef ctx = nsCtx.CGContext;

    // Flip coordinate system (NSBitmapImageRep uses top-left origin in CG)
    CGContextTranslateCTM(ctx, 0, size);
    CGContextScaleCTM(ctx, 1.0, -1.0);

    drawCryoIcon(ctx, (CGFloat)size);

    return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}


// ── main ─────────────────────────────────────────────────────────────────────
// Writes all icon PNGs directly into the xcassets appiconset directory.
// actool in build.sh then compiles them into the final AppIcon.icns.

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Output directory: Resources/AppIcon.xcassets/AppIcon.appiconset/
        NSString *xcassetsDir;
        if (argc >= 2) {
            xcassetsDir = [NSString stringWithUTF8String:argv[1]];
        } else {
            // Default: derive from executable location
            NSString *execDir = [[[NSBundle mainBundle] executablePath]
                                 stringByDeletingLastPathComponent];
            xcassetsDir = [[[execDir stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:@"Resources/AppIcon.xcassets"]
                           stringByAppendingPathComponent:@"AppIcon.appiconset"];
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *mkErr;
        if (![fm createDirectoryAtPath:xcassetsDir
           withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
            NSLog(@"✗  Cannot create directory %@: %@", xcassetsDir, mkErr.localizedDescription);
            return 1;
        }

        // Required sizes for macOS xcassets AppIcon
        struct { int pt; int scale; int px; } specs[] = {
            { 16,  1,  16   },
            { 16,  2,  32   },
            { 32,  1,  32   },
            { 32,  2,  64   },
            { 128, 1,  128  },
            { 128, 2,  256  },
            { 256, 1,  256  },
            { 256, 2,  512  },
            { 512, 1,  512  },
            { 512, 2,  1024 },
        };
        int count = sizeof(specs)/sizeof(specs[0]);

        NSLog(@"Rendering icon PNGs into xcassets...");
        for (int i = 0; i < count; i++) {
            int px = specs[i].px;
            NSString *name = specs[i].scale == 2
                ? [NSString stringWithFormat:@"icon_%dx%d@2x.png", specs[i].pt, specs[i].pt]
                : [NSString stringWithFormat:@"icon_%dx%d.png",    specs[i].pt, specs[i].pt];

            NSLog(@"  %@  (%dx%d px)", name, px, px);

            NSData *png = renderPNG(px);
            NSString *dest = [xcassetsDir stringByAppendingPathComponent:name];
            NSError *writeErr;
            if (![png writeToFile:dest options:NSDataWritingAtomic error:&writeErr]) {
                NSLog(@"✗  Failed: %@", writeErr.localizedDescription);
                return 1;
            }
        }

        NSLog(@"✓  All PNGs written to %@", xcassetsDir);
        NSLog(@"   Run actool in build.sh to compile → AppIcon.icns");
    }
    return 0;
}

