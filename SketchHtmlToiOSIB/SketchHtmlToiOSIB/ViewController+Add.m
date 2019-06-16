//
//  ViewController+Add.m
//  SketchHtmlToiOSIB
//
//  Created by dfpo on 2018/12/22.
//  Copyright © 2018 dfpo. All rights reserved.
//

#import "ViewController+Add.h"
#import "NSXMLElement+Add.m"
@implementation ViewController (Add)
#pragma mark - read save xml

- (NSXMLElement *)rootElementWithXmlFileName:(NSString *)xmlFileName {
    return (NSXMLElement *)[self documentWithXmlFileName:xmlFileName].rootElement;
}
- (NSXMLDocument *)documentWithXmlFileName:(NSString *)xmlFileName {
    
    NSError *error = nil;
    
    NSString *xmlFilePath = [[NSBundle mainBundle] pathForResource:xmlFileName
                                                            ofType:@"xml"];
    if (!xmlFilePath) {
        NSLog(@"找不到xml文件%@", xmlFileName);
        return [NSXMLDocument document];
    }
    NSData *xmlData = [NSData dataWithContentsOfFile:xmlFilePath options: 0 error: &error];
    if (error) {
        NSLog(@"error = %@",error);
        return [NSXMLDocument document];
    }
    NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData options:NSXMLNodePreserveWhitespace error:&error];
    return xmlDocument;
}
- (NSString *)getHtmlFilePathFromPath:(NSString *)htmlFilePath {
    BOOL isDir = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:htmlFilePath isDirectory:&isDir];
    if (!fileExists) {
        NSLog(@"文件不存在 %@", htmlFilePath);
        return nil;
    }
    NSString *rightHtmlFilePath = htmlFilePath.mutableCopy;
    if (!isDir) {
        
        if (![[htmlFilePath pathExtension] isEqualToString:@"html"]) {
            NSLog(@"应该传入html文件");
            return nil;
        }
        
    } else {
        /// 尝试查找传入文件夹内的 index.html
        // 获得当前文件夹path下面的所有内容（文件夹、文件）
        NSError *error = nil;
        NSArray<NSString *> *fileNames = [fm contentsOfDirectoryAtPath:htmlFilePath error:&error];
        if (error) {
            NSLog(@"出错了 %@", error);
            return nil;
        }
        /// 目标文件名
        NSString *desFileName = @"index.html";
        fileExists = [fileNames containsObject: desFileName];
        if (fileExists) {
            rightHtmlFilePath = [htmlFilePath stringByAppendingPathComponent:@"index.html"];
            return rightHtmlFilePath;
        }
    }
    return rightHtmlFilePath;
}
- (NSString *)jsonStrWithHtmlFileAtPath:(NSString *)htmlFilePath {
    
    NSString *rightHtmlFilePath = [self getHtmlFilePathFromPath:htmlFilePath];
    if(!rightHtmlFilePath) {
        NSLog(@"没找到html文件在路径 %@",htmlFilePath);
        return nil;
    }
    NSString *text = [NSString stringWithContentsOfFile:rightHtmlFilePath encoding:NSUTF8StringEncoding error:nil];
    NSString *startStr = @"SMApp(";
    NSUInteger start = [text rangeOfString: startStr].location;
    if (start == NSNotFound) {
        NSLog(@"未找到标准的数据");
        return nil;
    }
    start += startStr.length;
    NSString *endStr = @") });";
    NSUInteger end = [text rangeOfString: endStr options:(NSLiteralSearch|NSBackwardsSearch) range:NSMakeRange(start, text.length - start)].location;
    if (end == NSNotFound) {
        NSLog(@"结束标志");
        return nil;
    }
    NSString *subString = [text substringWithRange:NSMakeRange(start, end - start)];
    return subString ;
}

- (void)createSBFileAtPath:(NSString *)sbDesPath withObj:(NBSKObject *)object {
    if (!sbDesPath || !object) {
        return;
    }
    NSXMLDocument *sbDocument = [self documentWithXmlFileName:@"sb"];
    
    NSXMLElement *scenes =
    [sbDocument.rootElement firstElementByName:@"scenes"];
    [self.hud show:YES];
    for (ArtboardsItem *vc in object.artboards) {
        NSXMLElement *vcElement = [self getNewVCElement];
        NSArray <SKLayer *> *views = vc.layers;
        /// 设计稿 375*667
        CGFloat screenH = 667;
        NSArray<NSString *> *viewYs = [views valueForKeyPath:@"rect.y"];
        NSArray<NSString *> *viewHs = [views valueForKeyPath:@"rect.height"];
        NSMutableArray<NSNumber *> *maxYs = [NSMutableArray array];
        [viewYs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString * _Nonnull y, NSUInteger idx, BOOL * _Nonnull stop) {
            NSInteger aY = viewHs[idx].integerValue + y.integerValue;
            [maxYs addObject:@(aY)];
        }];
        
        CGFloat max =[[maxYs valueForKeyPath:@"@max.floatValue"] floatValue];
        if (screenH < max) {
            // 这里可以先添加一个scrollView在根view上，再添加其他子控件
            
            NSXMLElement *object = [vcElement firstElementByName:@"objects"];
            NSXMLElement *vc = [object firstElementByName:@"viewController"];
            NSArray<NSXMLElement *> *elements = (NSArray<NSXMLElement *> *)[vc elementsForName:@"size"];
            NSXMLElement *size;
            NSString *maxStr = @(max+20).stringValue;
            if (elements.count >= 1) {
                size =  elements[0];
                [self setValue:@"freeformSize" forKey:@"key" forElement:size];
                [self setValue:@"375" forKey:@"width" forElement:size];
                [self setValue: maxStr forKey:@"height" forElement:size];
            } else {
                size = [NSXMLElement elementWithName:@"size"];
                [self setValue:@"freeformSize" forKey:@"key" forElement:size];
                [self setValue:@"375" forKey:@"width" forElement:size];
                [self setValue: maxStr forKey:@"height" forElement:size];
                [vc addChild:size];
            }
            
            
        }
        
        for (SKLayer *view in views) {
            if (!view.objectID) {
                continue;
            }
            if (view.rect.x.intValue <= 16 &&
                view.rect.y.intValue <= 36 &&
                view.rect.width.intValue <= 9 &&
                view.rect.height.intValue <= 26 ) {
                /// 不添加把返回按钮
                continue;
            } else if (view.rect.y.intValue < 20 &&
                       view.rect.height.intValue <= 20 ) {
                // 不添加状态栏上的控件
                continue;
            }
            /// 控件类别 text为lable， slice为图片，shape为view
            NSString *viewType = view.type;
            /// 将要被添加的新的 view NSXMLElement 对象
            NSXMLElement *aNewWillBeAddedViewElement;
            NSString *vcTitle;
#pragma mark - UILabel
            if ([viewType isEqualToString:@"text"]) {
                NSXMLElement *labelElement = [self getNewlabelElement];
                [self setRect:view.rect forElement:labelElement];
                if ([view.content isEqualToString: @"跟进"]) {
                    NSLog(@"---%@---",@"fd");
                }
                labelElement.text = view.content;
                // [self setText:view.textAlign ForElement:labelElement];
                labelElement.fontSize = view.fontSize;
                /// 这里用 r g b a除 255 更精准
                /// 之前用 view.color.uiColor (r:0.77 g:0.77 b:0.77 a:1.00)
                /// 丢失了精准
                NSString *newColor = [NSString stringWithFormat:@"(r:%f g:%f b:%f a:1.00)",view.color.r/255.0, view.color.g/255.0, view.color.b/255.0];
                labelElement.textColor = newColor;
                if ([view.rect.y isEqualToString: @"30"]||
                    [view.rect.y isEqualToString: @"31"]) {
                    //可能是标题
                    vcTitle = view.content;
                }
                labelElement.fontStyle = view.fontFace;
                aNewWillBeAddedViewElement = labelElement;
            }else if ([viewType isEqualToString:@"slice"]) {//图片
#pragma mark - UIImageView
                
                NSXMLElement *imgElement = [self getNewImageViewElement];
                [self setRect:view.rect forElement:imgElement];
                // image="fff.png"
                aNewWillBeAddedViewElement = imgElement;
                
            }else if ([viewType isEqualToString:@"shape"]) {//view
#pragma mark - UIView
                
                NSXMLElement *viewElement = [self getNewViewElement];
                [self setRect:view.rect forElement:viewElement];
                if (view.fills && view.fills.count > 0) {
                    viewElement.backgroundColor = view.fills[0].color.uiColor ;
                }
                if (view.css && view.css.count > 0) {
                    [self setViewCss:view.css ForElement:viewElement];
                }
                aNewWillBeAddedViewElement = viewElement;
                
            } else {
                NSLog(@"--未知类型--%@---", viewType);
            }
            if (view.opacity) {
                [self setAlpha:view.opacity ForElement:aNewWillBeAddedViewElement];
            }
            if (vcTitle) {
                [self setLable:vcTitle forVCElement:vcElement];
            } else {
                [self setLable:vc.name forVCElement:vcElement];
            }
            if (aNewWillBeAddedViewElement) {
                NSArray<NSXMLElement *> *rootViewSubViewElements = [self getSubViewElementInVCElement:vcElement];
                NSMutableArray<SKRect *> *rootViewSubViewSKRects = [NSMutableArray array];
                for (NSXMLElement *rootViewSubViewElement in rootViewSubViewElements) {
                    [rootViewSubViewSKRects addObject: [self getSKRectFromElement:rootViewSubViewElement]];
                }
                /// 将要被添加的新的 view NSXMLElement 对象的 CGRect值
                CGRect aNewWillBeAddedViewRect = [self getCGRectFromElement: aNewWillBeAddedViewElement];;
                BOOL hasSuperViewInRootView = NO;
                for (SKRect *rootViewSubViewSKRect in rootViewSubViewSKRects) {
                    
                    CGRect superViewInRootViewCGRect =
                        [self getCGRectFromSKRect:rootViewSubViewSKRect];
                    
                    if ( CGRectContainsRect(superViewInRootViewCGRect, aNewWillBeAddedViewRect) ) {
                        hasSuperViewInRootView = YES;
                        
                        NSUInteger findedSuperViewIdx =
                            [rootViewSubViewSKRects indexOfObject: rootViewSubViewSKRect];
                        
                        NSXMLElement *superViewInRootViewElement =
                            rootViewSubViewElements[findedSuperViewIdx];
                        
                        /// 再找一找父控件里，又包含自己的真正父控件
                        NSArray<NSXMLElement *> *superViewInRootViewSubElements =
                        [self getSubViewElementInElement: superViewInRootViewElement];
//
                        NSMutableArray<SKRect *> *superViewInRootViewSubSKRects = [NSMutableArray array];
                        for (NSXMLElement *superViewInRootViewSubElement in superViewInRootViewSubElements) {
                            [superViewInRootViewSubSKRects addObject: [self getSKRectFromElement: superViewInRootViewSubElement]];
                        }
                        /// 在父控件里又有父控件
                        BOOL hasSuperViewInSuperView = NO;
                        for (SKRect *superViewInRootViewSubSKRect in superViewInRootViewSubSKRects) {
//
                            CGRect superViewInSuperViewCGRect = [self getCGRectFromSKRect: superViewInRootViewSubSKRect];
////
                            if ( CGRectContainsRect(superViewInSuperViewCGRect, aNewWillBeAddedViewRect) ) {
                                hasSuperViewInSuperView = YES;
//
                                NSUInteger findedSuperViewInSuperViewIdx = [superViewInRootViewSubSKRects indexOfObject:superViewInRootViewSubSKRect];
                                NSXMLElement *findedSuperViewInSuperViewElement = superViewInRootViewSubElements[findedSuperViewInSuperViewIdx];
                                [self moveSubviewElement: aNewWillBeAddedViewElement
                                      toSuperViewElement: findedSuperViewInSuperViewElement];
                                break;
                            } else  {
                                SKRect *oldSelfR = [self getSKRectFromElement:aNewWillBeAddedViewElement];
                                oldSelfR.x = [NSString stringWithFormat:@"%zd", (oldSelfR.x.integerValue - superViewInRootViewSubSKRect.x.integerValue)];
                                oldSelfR.y = [NSString stringWithFormat:@"%zd", (oldSelfR.y.integerValue - superViewInRootViewSubSKRect.y.integerValue)];
                                
                                /// 放入的新控件，可以当做现在某个子控件的父控件
                                if ( CGRectContainsRect(aNewWillBeAddedViewRect, [self getCGRectFromSKRect:oldSelfR]) ) {
                                    // 把之前的控件，移动到新控件内
//                                    NSUInteger findedSuperViewInSuperViewIdx = [superViewInRootViewSubSKRects indexOfObject:superViewInRootViewSubSKRect];
//                                    NSXMLElement *findedSuperViewInSuperViewElement = superViewInRootViewSubElements[findedSuperViewInSuperViewIdx];
//                                    [superViewInRootViewElement removeChildAtIndex:findedSuperViewInSuperViewIdx];
                                    // todo 将之前的移动到新的上
//                                    NSXMLElement *aNew = findedSuperViewInSuperViewElement.copy;
//                                    [self setRandomIdForElement:aNew];
//                                    [self moveSubviewElement: aNew
//                                          toSuperViewElement: aNewWillBeAddedViewElement];
                                    break;
                                }
                            }
//
                        }
                        if (!hasSuperViewInSuperView) {
//                            //  在根view下面没有找到了父控件，就加入到根view下
                            
                            [self moveSubviewElement: aNewWillBeAddedViewElement
                                  toSuperViewElement: superViewInRootViewElement];
                        } else {
                            NSLog(@"---%@---",@"ff");
                        }
                        
                        break;
                    }
                    
                }
                if (!hasSuperViewInRootView) {
                    //  在根view下面没有找到了父控件，就加入到根view下
                    [self addSubviewElement:aNewWillBeAddedViewElement
                                inVCElement:vcElement
                             fromSbDocument:sbDocument];
                } else {
                    NSLog(@"---%@---",@"ff");
                }
            }
        }
        // 尝试加入按钮
        NSArray<NSXMLElement *> *rootViewSubViewElements = [self getSubViewElementInVCElement:vcElement];
        [rootViewSubViewElements enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull rootViewSubE, NSUInteger idx, BOOL * _Nonnull stop) {
            NSArray<NSXMLElement *> *subEs = [self getSubViewElementInElement: rootViewSubE];
            if (subEs.count == 1) {
                if ([rootViewSubE.name isEqualToString: @"view"] &&
                    [subEs[0].name isEqualToString: @"label"]) {
                    NSXMLElement *label = subEs[0];
                    // view 包含一个  label
                    NSXMLElement *button = [self getNewButtonElement];
                    // 更新button frame
                    [self setRect: [self getSKRectFromElement:rootViewSubE] forElement:button];
                   // 更新 bgColor
                    button.backgroundColor = rootViewSubE.backgroundColor;
                    // normal 状态下的文字
                    [self setNormalText: label.text forButtonElement:button];
                    // normal 状态下的字色 字号大小
                    button.fontSize = label.fontSize;
                    button.fontStyle = label.fontStyle;
                    button.normalTitleColor = label.textColor;
                    [self addSubviewElement:button inVCElement:vcElement fromSbDocument:sbDocument];
                }
            }
        }];
        [scenes addChild: vcElement];
        self.hud.progress = (scenes.childCount+1)/(object.artboards.count+1);
        self.hud.labelText = [NSString stringWithFormat:@"%tu/%tu",scenes.childCount,object.artboards.count];
        if (scenes.childCount == object.artboards.count) {
            NSLog(@"----%@---", @"写入完成");
            [[NSWorkspace sharedWorkspace] selectFile:sbDesPath inFileViewerRootedAtPath:sbDesPath];
            
            [[NSWorkspace sharedWorkspace] openFile:sbDesPath withApplication:@"Xcode"];
        }
        
    }
    
    [self saveXMLDoucment:sbDocument toPath:sbDesPath];
    [self.hud hide:YES];
    
}
/// 输出storyboard
- (BOOL)saveXMLDoucment:(NSXMLDocument *)XMLDoucment toPath:(NSString *)destPath {
    
    if (XMLDoucment == nil) {
        return NO;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExist = [fm fileExistsAtPath:destPath];
    if ( fileExist) {
        [fm removeItemAtPath:destPath error:nil];
    } else {
        if ( ![fm createFileAtPath:destPath contents:nil attributes:nil]){
            NSLog(@"创建文件失败 %@", destPath);
            return NO;
        }
    }
    
    NSData *XMLData = [XMLDoucment XMLDataWithOptions:NSXMLNodePrettyPrint];
    if (![XMLData writeToFile:destPath atomically:YES]) {
        NSLog(@"Could not write document out...");
        return NO;
    }
    return YES;
}
#pragma mark - get view add view
/// 移动子元素到父元素内，添加子view到其父view上
- (void)moveSubviewElement:(NSXMLElement *)subViewElement toSuperViewElement:(NSXMLElement *)superViewElement {
    
    if (!subViewElement) {
        NSLog(@"未找到 %@", subViewElement);
        return;
    }
    if (!superViewElement) {
        NSLog(@"未找到 %@", superViewElement);
        return;
    }
    NSXMLElement *subViewSuperView = [superViewElement firstElementByName:@"subviews"];
    if ([superViewElement.name isEqualToString:@"label"] ||
        [superViewElement.name isEqualToString:@"imageView"] ||
        [superViewElement.name isEqualToString:@"button"]) {
        
        return;
    }
    NSLog(@"--ccccccccc-%@---", superViewElement.name);
    SKRect *oldSuperR = [self getSKRectFromElement:superViewElement];
    
    SKRect *oldSelfR = [self getSKRectFromElement:subViewElement];
    /// 更新 移动到父控件里的x y
    oldSelfR.x = [NSString stringWithFormat:@"%zd", (oldSelfR.x.integerValue - oldSuperR.x.integerValue)];
    oldSelfR.y = [NSString stringWithFormat:@"%zd", (oldSelfR.y.integerValue - oldSuperR.y.integerValue)];
    
    [self setRect:oldSelfR forElement:subViewElement];
    // 考虑 更新 x y
    [subViewSuperView addChild:subViewElement];
    
}
- (NSArray<NSXMLElement *> *)getSubViewElementInVCElement:(NSXMLElement *)vcElement {
    if (!vcElement) {
        NSLog(@"未找到 %@", vcElement);
        return @[];
    }
    NSXMLElement *object = [vcElement firstElementByName:@"objects"];
    NSXMLElement *vc = [object firstElementByName:@"viewController" ];
    NSXMLElement *view = [vc firstElementByName:@"view"];
    NSXMLElement *subViewSuperView = [view firstElementByName:@"subviews"];
    return subViewSuperView.children;
}
- (NSArray<NSXMLElement *> *)getSubViewElementInElement:(NSXMLElement *)viewElement {
    if (!viewElement) {
        NSLog(@"未找到 %@", viewElement);
        return @[];
    }
    NSXMLElement *subViewSuperView = [viewElement firstElementByName:@"subviews"];
    return subViewSuperView.children;
}
- (void)addSubviewElement:(NSXMLElement *)subViewElement inVCElement:(NSXMLElement *)vcElement fromSbDocument:(NSXMLDocument *)sbDocument{
    if (!subViewElement) {
        NSLog(@"未找到 %@", subViewElement);
        return;
    }
    if (!vcElement) {
        NSLog(@"未找到 %@", vcElement);
        return;
    }
    NSXMLElement *object = [vcElement firstElementByName:@"objects" ];
    NSXMLElement *vc = [object firstElementByName:@"viewController" ];
    NSXMLElement *view = [vc firstElementByName:@"view"];
    NSXMLElement *subViewSuperView = [view firstElementByName:@"subviews"];
    /// 限制加入子控件的个数
    //    if (subViewSuperView.childCount > 80) {
    if ([subViewElement.name isEqualToString:@"label"]) {
        NSString *labelText = [subViewElement attributeForName:@"text"].stringValue;
        NSNumber *preCount = self.labelCountDict[labelText];
        if (!preCount || [preCount isEqual:@0]) {
            self.labelCountDict[labelText] = @1;
        } else {
            self.labelCountDict[labelText] = @(preCount.intValue + 1);
        }
        if (self.labelCountDict[labelText].intValue > 80) {
            NSLog(@"--%@--%@---", @"添加太多一样的label了", labelText);
            return;
        }
    }
    //    }
    
    [subViewSuperView addChild:subViewElement];
    /// 暂不处理图片信息
    return;
    if ([subViewElement.name isEqualToString:@"imageView"]) {
        //如果添加imageView 得<image name="fff.png" width="16" height="16"/>
        
        NSXMLElement *imageNode = [NSXMLElement elementWithName:@"image"];
        NSString *imgName = [subViewElement attributeForName:@"image"].stringValue;
        
        if (imgName && imgName.length > 0) {
            [imageNode addAttribute:[NSXMLNode attributeWithName:@"name" stringValue: imgName]];
            [imageNode addAttribute:[NSXMLNode attributeWithName:@"width" stringValue:@"16"]];
            [imageNode addAttribute:[NSXMLNode attributeWithName:@"height" stringValue:@"16"]];
            NSXMLElement *resources =
            [sbDocument.rootElement firstElementByName:@"resources"];
            [resources addChild:imageNode.copy];
        }
    }
}
- (NSXMLElement *)getNewVCElement {
    NSXMLElement *vcElement = [self rootElementWithXmlFileName:@"vc"];
    [self setRandomIdForElement:vcElement];
    NSXMLElement *objects = [vcElement firstElementByName:@"objects"];
    NSXMLElement *placeholder = [objects firstElementByName:@"placeholder"];
    [self setRandomIdForElement:placeholder];
    
    NSXMLElement *viewController = [objects firstElementByName:@"viewController"];
    [self setRandomIdForElement:viewController];
    
    
    NSXMLElement *view = [viewController firstElementByName:@"view" ];
    [self setRandomIdForElement:view];
    NSXMLElement *viewLayoutGuide = [view firstElementByName:@"viewLayoutGuide" ];
    [self setRandomIdForElement:viewLayoutGuide];
    
    return vcElement.copy;
}
- (NSXMLElement *)getNewlabelElement {
    NSXMLElement *lableElement = [self rootElementWithXmlFileName:@"label"];
    [self setRandomIdForElement:lableElement];
    return lableElement.copy;
}
- (NSXMLElement *)getNewButtonElement {
    NSXMLElement *lableElement = [self rootElementWithXmlFileName:@"button"];
    [self setRandomIdForElement:lableElement];
    return lableElement.copy;
}
/// name imageView"
- (NSXMLElement *)getNewImageViewElement {
    NSXMLElement *imgVElement = [self rootElementWithXmlFileName:@"imageView"];
    [self setRandomIdForElement:imgVElement];
    return imgVElement.copy;
}
- (NSXMLElement *)getNewViewElement {
    NSXMLElement *viewElement = [self rootElementWithXmlFileName:@"view"];
    [self setRandomIdForElement:viewElement];
    return viewElement.copy;
}
- (void)setRandomIdForElement:(NSXMLElement *)element {
    NSArray<NSXMLNode *> *nodes = element.attributes;
    NSString *name = [element.name isEqualToString:@"scene"]?@"sceneID":@"id";
    for (NSXMLNode *node in nodes) {
        if ([node.name isEqualToString: name]) {
            [node setStringValue:[self randomid]];
        }
    }
}

/// 获取某个元素的 frame
- (SKRect *)getSKRectFromElement:(NSXMLElement *)element{
    
    SKRect *skr = [SKRect new];
    NSXMLElement *rectElement = [element firstElementByName:@"rect"];
    NSArray<NSXMLNode *> *nodes = rectElement.attributes;
    for (NSXMLNode *node in nodes) {
        if ([node.name isEqualToString: @"x"]) {
            skr.x = node.stringValue;
        } else if ([node.name isEqualToString: @"y"]) {
            skr.y = node.stringValue;
        } else if ([node.name isEqualToString: @"width"]) {
            skr.width = node.stringValue;
        } else if ([node.name isEqualToString: @"height"]) {
            skr.height = node.stringValue;
        }
    }
    
    return skr;
}
- (CGRect)getCGRectFromElement:(NSXMLElement *)element{
    
    SKRect *desSR = [self  getSKRectFromElement:element];
    return [self getCGRectFromSKRect:desSR];
}
- (CGRect)getCGRectFromSKRect:(SKRect *)desSR {
    CGRect rect =
    CGRectMake(desSR.x.floatValue, desSR.y.floatValue, desSR.width.floatValue, desSR.height.floatValue);
    return rect;
}
/// 设置某个元素的 frame
- (void)setRect:(SKRect *)rect forElement:(NSXMLElement *)element{
    NSXMLElement *rectElement = [element firstElementByName:@"rect"];
    NSArray<NSXMLNode *> *nodes = rectElement.attributes;
    for (NSXMLNode *node in nodes) {
        if ([node.name isEqualToString: @"x"]) {
            [node setStringValue: rect.x];
        } else if ([node.name isEqualToString: @"y"]) {
            [node setStringValue: rect.y];
        } else if ([node.name isEqualToString: @"width"]) {
            [node setStringValue: rect.width];
            if ([element.name isEqualToString:@"label"]) {
                /// 修复lable宽度，自动布局时，宽度自适应
                NSString *fixW = @(rect.width.integerValue+6).stringValue;
                [node setStringValue: fixW];
            }
        } else if ([node.name isEqualToString: @"height"]) {
            [node setStringValue: rect.height];
        }
    }
}
-(void)setNormalText:(NSString *)text forButtonElement:(NSXMLElement *)element {
    if (![element.name isEqualToString: @"button"]) {
        return;
    }
    /*
     <button>
     <state key="normal" title="Button"/>
     <state key="selected" title="4343434"/>
     </button>
     */
    NSXMLElement *stateTextElement = [element firstElementByName:@"state"];
    NSArray<NSXMLNode *> *nodes = stateTextElement.attributes;
    for (NSXMLNode *node in nodes) {
        if ([node.name isEqualToString: @"key"]) {
            // 状态
        } else if ([node.name isEqualToString: @"title"]) {
            // 文字内容
            [node setStringValue: text];
        }
    }
}

-(void)setAlpha:(NSString *)alpha ForElement:(NSXMLElement *)element{
    if ([alpha isEqualToString:@"1"]) {
        return;
    }
    NSString *key = @"alpha";
    [self setValue:alpha forKey:key forElement:element];
}


-(void)setTextAlign:(NSString *)textAlign forLabelElement:(NSXMLElement *)element{
#pragma mark - to do
    __unused NSString *key = @"textAlignment";
    //    [self setValue:textAlign forKey:key forElement:element];
}

-(void)setViewCss:(NSArray <NSString *> *)css ForElement:(NSXMLElement *)element {
#pragma mark - to do
    // ["border: 1px solid #295DFD;","border-radius: 4px;"]
    [css enumerateObjectsUsingBlock:^(NSString * _Nonnull str, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([str hasPrefix:@"border:"]) {
            
        } else if ([str hasPrefix:@"border-radius:"]) {
            
        }
    }];
}
-(void)setLable:(NSString *)text forVCElement:(NSXMLElement *)element {
    NSString *input = text;
    BOOL hasValue = input && input.length > 0;
    if (!hasValue) {
        return;
    }
    NSXMLElement *objects =  [element firstElementByName:@"objects" ];
    NSXMLElement *viewController =  [objects firstElementByName:@"viewController" ];
    
    NSString *key = @"userLabel";
    [self setValue:text forKey:key forElement:viewController];
}

- (void)setValue:(NSString *)value forKey:(NSString *)key  forElement:(NSXMLElement *)element {
    if (!key || !value || !element) {
        return;
    }
    BOOL hasKey = [element attributeForName: key].name.length;
    if (hasKey) {
        NSString *valueStr = [element attributeForName: key].stringValue;
        if ([value isEqualToString:valueStr]) {
            return;
        }
        [element setAttributesAsDictionary: @{key:value}];
    } else {
        [element addAttribute:[NSXMLNode attributeWithName:key stringValue: value]];
    }
}
#pragma mark - id
-(NSString *)randomid {
    
    NSString *str1 = [self randomStrWithLength:3];
    NSString *str2 = [self randomStrWithLength:2];
    NSString *str3 = [self randomStrWithLength:3];
    return [@[str1, str2, str3] componentsJoinedByString:@"-"];
}
- (NSString *)randomStrWithLength:(NSUInteger)len {
    
    NSString * strAll = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSString * result = [[NSMutableString alloc]initWithCapacity:16];
    for (int i = 0; i < len; i++)
    {
        //获取随机数
        NSInteger index = arc4random() % (strAll.length-1);
        char tempStr = [strAll characterAtIndex:index];
        result = (NSMutableString *)[result stringByAppendingString:[NSString stringWithFormat:@"%c",tempStr]];
    }
    
    return result;
}
#pragma mark - other

- (NSDictionary *)dicWithJsonStr:(NSString *)jsonString{
    if (!jsonString) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

@end
