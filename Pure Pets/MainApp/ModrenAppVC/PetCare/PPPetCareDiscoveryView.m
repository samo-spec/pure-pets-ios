#import "PPPetCareDiscoveryView.h"
#import "PPDesignTokens.h"
#import "AppClasses.h"

static UIFont *PPCareFont(CGFloat size, UIFontTextStyle style, BOOL emphasized, UITraitCollection *traits)
{
    UIFont *font = emphasized ? [GM boldFontWithSize:size] : [GM MidFontWithSize:size];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:font compatibleWithTraitCollection:traits];
}

static UILabel *PPCareLabel(void)
{
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh + 1 forAxis:UILayoutConstraintAxisVertical];
    return label;
}

static UIButton *PPCareButton(NSString *identifier)
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityIdentifier = identifier;
    button.titleLabel.numberOfLines = 0;
    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin];
    NSLayoutConstraint *width = [button.widthAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin];
    height.priority = width.priority = 999; // UIStackView may hide an action while loading.
    [NSLayoutConstraint activateConstraints:@[height, width]];
    return button;
}

@implementation PPPetCareDiscoveryView {
    UIStackView *_stack;
    UIStackView *_modeStack;
    UIStackView *_scopeStack;
    UIStackView *_resultStack;
    UILabel *_title;
    UILabel *_subtitle;
    UILabel *_resultLabel;
    UILabel *_retainedLabel;
    UIView *_searchSurface;
    UIImageView *_searchIcon;
    UIView *_careContainer;
    UIImageView *_careMark;
    LOTAnimationView *_careLottieView;
    BOOL _careLottieLoaded;
    UIView *_stateSurface;
    UIStackView *_stateStack;
    UIImageView *_stateIcon;
    UILabel *_stateTitle;
    UILabel *_stateMessage;
    UIActivityIndicatorView *_activity;
    UIView *_selectionLine;
    UIView *_modeSeparator;
    NSLayoutConstraint *_selectionCenter;
    NSLayoutConstraint *_selectionWidth;
    PPPetCareInitialSection _selectedSection;
    BOOL _hasConfiguration;
    BOOL _loading;
    PPPetCareDiscoveryState _state;
    NSString *_kindName;
    NSString *_filterName;
    NSUInteger _count;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.accessibilityIdentifier = @"petCare.discovery";
    _stack = [[UIStackView alloc] init];
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = PPSpaceBase;
    [self addSubview:_stack];
    NSLayoutConstraint *preferredWidth = [_stack.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-2 * PPScreenMargin];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [_stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSpaceBase],
        [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSpaceSM],
        [_stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:PPScreenMargin],
        [_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-PPScreenMargin],
        [_stack.widthAnchor constraintLessThanOrEqualToConstant:920], preferredWidth
    ]];

    _title = PPCareLabel();
    _title.accessibilityTraits = UIAccessibilityTraitHeader;
    _subtitle = PPCareLabel();
    UIStackView *introCopy = [[UIStackView alloc] initWithArrangedSubviews:@[_title, _subtitle]];
    introCopy.axis = UILayoutConstraintAxisVertical;
    introCopy.spacing = PPSpaceXS;
    _careContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 124.0, 62.0)];
    _careContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _careContainer.backgroundColor = UIColor.clearColor;
    _careContainer.clipsToBounds = NO;
    _careContainer.isAccessibilityElement = NO;
    NSLayoutConstraint *markWidth = [_careContainer.widthAnchor constraintEqualToConstant:124.0];
    markWidth.priority = 999;
    markWidth.active = YES;
    NSLayoutConstraint *markHeight = [_careContainer.heightAnchor constraintEqualToConstant:62.0];
    markHeight.priority = 999;
    markHeight.active = YES;
    [_careContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_careContainer setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _careMark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"cross.case"]];
    _careMark.translatesAutoresizingMaskIntoConstraints = NO;
    _careMark.contentMode = UIViewContentModeScaleAspectFit;
    _careMark.isAccessibilityElement = NO;
    _careMark.tintColor = AppPrimaryClr;
    [_careContainer addSubview:_careMark];

    _careLottieView = [[LOTAnimationView alloc] initWithFrame:CGRectMake(0, 0, 124.0, 62.0)];
    _careLottieView.translatesAutoresizingMaskIntoConstraints = NO;
    _careLottieView.contentMode = UIViewContentModeScaleAspectFit;
    _careLottieView.backgroundColor = UIColor.clearColor;
    _careLottieView.opaque = NO;
    _careLottieView.loopAnimation = YES;
    _careLottieView.animationSpeed = 0.5;
    _careLottieView.isAccessibilityElement = NO;
    _careLottieView.alpha = 0.0;
    _careLottieView.hidden = YES;
    [_careContainer addSubview:_careLottieView];

    [NSLayoutConstraint activateConstraints:@[
        [_careMark.centerXAnchor constraintEqualToAnchor:_careContainer.centerXAnchor],
        [_careMark.centerYAnchor constraintEqualToAnchor:_careContainer.centerYAnchor],
        [_careMark.widthAnchor constraintEqualToConstant:38.0],
        [_careMark.heightAnchor constraintEqualToConstant:38.0],

        [_careLottieView.leadingAnchor constraintEqualToAnchor:_careContainer.leadingAnchor],
        [_careLottieView.trailingAnchor constraintEqualToAnchor:_careContainer.trailingAnchor],
        [_careLottieView.topAnchor constraintEqualToAnchor:_careContainer.topAnchor],
        [_careLottieView.bottomAnchor constraintEqualToAnchor:_careContainer.bottomAnchor]
    ]];

    UIStackView *intro = [[UIStackView alloc] initWithArrangedSubviews:@[introCopy, _careContainer]];
    intro.alignment = UIStackViewAlignmentTop;
    intro.spacing = PPSpaceBase;
    [_stack addArrangedSubview:intro];

    [self pp_loadCareLottieAnimation];

    _medicineButton = PPCareButton(@"petCare.medicines");
    _vetsButton = PPCareButton(@"petCare.veterinarians");
    _clinicsButton = PPCareButton(@"petCare.clinics");
    _medicineButton.tag = PPPetCareInitialSectionMedicines;
    _vetsButton.tag = PPPetCareInitialSectionVeterinarians;
    _clinicsButton.tag = PPPetCareInitialSectionClinics;
    UIView *modeSurface = [[UIView alloc] init];
    _modeStack = [[UIStackView alloc] initWithArrangedSubviews:@[_medicineButton, _vetsButton, _clinicsButton]];
    _modeStack.translatesAutoresizingMaskIntoConstraints = NO;
    _modeStack.distribution = UIStackViewDistributionFillEqually;
    _modeStack.spacing = PPSpaceSM;
    [modeSurface addSubview:_modeStack];
    _modeSeparator = [[UIView alloc] init];
    _modeSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [modeSurface addSubview:_modeSeparator];
    _selectionLine = [[UIView alloc] init];
    _selectionLine.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionLine.layer.cornerRadius = 1.5;
    _selectionLine.isAccessibilityElement = NO;
    [modeSurface addSubview:_selectionLine];
    [NSLayoutConstraint activateConstraints:@[
        [_modeStack.topAnchor constraintEqualToAnchor:modeSurface.topAnchor],
        [_modeStack.leadingAnchor constraintEqualToAnchor:modeSurface.leadingAnchor],
        [_modeStack.trailingAnchor constraintEqualToAnchor:modeSurface.trailingAnchor],
        [_modeStack.bottomAnchor constraintEqualToAnchor:modeSurface.bottomAnchor constant:-PPSpaceSM],
        [_modeSeparator.leadingAnchor constraintEqualToAnchor:modeSurface.leadingAnchor],
        [_modeSeparator.trailingAnchor constraintEqualToAnchor:modeSurface.trailingAnchor],
        [_modeSeparator.bottomAnchor constraintEqualToAnchor:modeSurface.bottomAnchor],
        [_modeSeparator.heightAnchor constraintEqualToConstant:0.5],
        [_selectionLine.bottomAnchor constraintEqualToAnchor:modeSurface.bottomAnchor],
        [_selectionLine.heightAnchor constraintEqualToConstant:3]
    ]];
    [_stack addArrangedSubview:modeSurface];

    _searchSurface = [[UIView alloc] init];
    PPApplyContinuousCorners(_searchSurface, PPCorner16);
    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.adjustsFontForContentSizeCategory = YES;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchField.accessibilityIdentifier = @"petCare.search";
    _searchField.inputAssistantItem.leadingBarButtonGroups = @[];
    _searchField.inputAssistantItem.trailingBarButtonGroups = @[];
    _searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    _searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    _searchIcon.isAccessibilityElement = NO;
    [_searchSurface addSubview:_searchIcon];
    [_searchSurface addSubview:_searchField];
    [NSLayoutConstraint activateConstraints:@[
        [_searchSurface.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG],
        [_searchIcon.leadingAnchor constraintEqualToAnchor:_searchSurface.leadingAnchor constant:PPSpaceBase],
        [_searchIcon.centerYAnchor constraintEqualToAnchor:_searchSurface.centerYAnchor],
        [_searchIcon.widthAnchor constraintEqualToConstant:20],
        [_searchIcon.heightAnchor constraintEqualToConstant:20],
        [_searchField.leadingAnchor constraintEqualToAnchor:_searchIcon.trailingAnchor constant:PPSpaceMD],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchSurface.trailingAnchor constant:-PPSpaceMD],
        [_searchField.topAnchor constraintEqualToAnchor:_searchSurface.topAnchor constant:PPSpaceMD],
        [_searchField.bottomAnchor constraintEqualToAnchor:_searchSurface.bottomAnchor constant:-PPSpaceMD]
    ]];
    [_stack addArrangedSubview:_searchSurface];
    [_stack setCustomSpacing:PPSpaceXS afterView:_searchSurface];

    _kindButton = PPCareButton(@"petCare.petKind");
    _filterButton = PPCareButton(@"petCare.filters");
    _kindButton.showsMenuAsPrimaryAction = YES;
    _filterButton.showsMenuAsPrimaryAction = YES;
    _scopeStack = [[UIStackView alloc] initWithArrangedSubviews:@[_kindButton, _filterButton]];
    _scopeStack.spacing = PPSpaceSM;
    _scopeStack.distribution = UIStackViewDistributionFillEqually;
    [_stack addArrangedSubview:_scopeStack];
    [_stack setCustomSpacing:PPSpaceXS afterView:_scopeStack];

    _resultLabel = PPCareLabel();
    _resultLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _refreshButton = PPCareButton(@"petCare.refresh");
    _activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _activity.hidesWhenStopped = YES;
    _resultStack = [[UIStackView alloc] initWithArrangedSubviews:@[_resultLabel, _activity, _refreshButton]];
    _resultStack.alignment = UIStackViewAlignmentCenter;
    _resultStack.spacing = PPSpaceSM;
    [_refreshButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_stack addArrangedSubview:_resultStack];
    [_stack setCustomSpacing:PPSpaceSM afterView:_resultStack];

    _retainedLabel = PPCareLabel();
    [_stack addArrangedSubview:_retainedLabel];

    _stateSurface = [[UIView alloc] init];
    PPApplyContinuousCorners(_stateSurface, PPCornerCard);
    _stateStack = [[UIStackView alloc] init];
    _stateStack.translatesAutoresizingMaskIntoConstraints = NO;
    _stateStack.axis = UILayoutConstraintAxisVertical;
    _stateStack.spacing = PPSpaceMD;
    [_stateSurface addSubview:_stateStack];
    NSLayoutConstraint *stateBottom = [_stateStack.bottomAnchor constraintEqualToAnchor:_stateSurface.bottomAnchor constant:-PPSpaceLG];
    stateBottom.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [_stateStack.topAnchor constraintEqualToAnchor:_stateSurface.topAnchor constant:PPSpaceXL],
        [_stateStack.leadingAnchor constraintEqualToAnchor:_stateSurface.leadingAnchor constant:PPSpaceLG],
        [_stateStack.trailingAnchor constraintEqualToAnchor:_stateSurface.trailingAnchor constant:-PPSpaceLG],
        stateBottom
    ]];
    UIView *iconLine = [[UIView alloc] init];
    _stateIcon = [[UIImageView alloc] init];
    _stateIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _stateIcon.contentMode = UIViewContentModeScaleAspectFit;
    _stateIcon.isAccessibilityElement = NO;
    [iconLine addSubview:_stateIcon];
    [NSLayoutConstraint activateConstraints:@[
        [_stateIcon.leadingAnchor constraintEqualToAnchor:iconLine.leadingAnchor],
        [_stateIcon.topAnchor constraintEqualToAnchor:iconLine.topAnchor],
        [_stateIcon.bottomAnchor constraintEqualToAnchor:iconLine.bottomAnchor],
        [_stateIcon.widthAnchor constraintEqualToConstant:32],
        [_stateIcon.heightAnchor constraintEqualToConstant:32]
    ]];
    [_stateStack addArrangedSubview:iconLine];
    _stateTitle = PPCareLabel();
    _stateTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    _stateMessage = PPCareLabel();
    [_stateStack addArrangedSubview:_stateTitle];
    [_stateStack setCustomSpacing:PPSpaceXS afterView:_stateTitle];
    [_stateStack addArrangedSubview:_stateMessage];
    _primaryButton = PPCareButton(@"petCare.recovery");
    [_stateStack addArrangedSubview:_primaryButton];
    [_stack addArrangedSubview:_stateSurface];
    _alternateButton = PPCareButton(@"petCare.otherSection");
    [_stack addArrangedSubview:_alternateButton];
    return self;
}

- (void)styleButton:(UIButton *)button title:(NSString *)title symbol:(NSString *)symbol selected:(BOOL)selected filled:(BOOL)filled
{
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = title;
    configuration.image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
    configuration.imagePadding = PPSpaceSM;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceMD, PPSpaceMD, PPSpaceMD);
    configuration.baseForegroundColor = selected ? AppPrimaryClr : AppPrimaryTextClr;
    configuration.background.backgroundColor = filled ? [AppPrimaryClr colorWithAlphaComponent:0.08] : UIColor.clearColor;
    configuration.background.cornerRadius = PPCornerSmall;
    UIFont *font = PPCareFont(PPFontCallout, UIFontTextStyleCallout, selected, self.traitCollection);
    configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[NSFontAttributeName] = font;
        return result;
    };
    button.configuration = configuration;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
}

- (void)configureForVeterinarians:(BOOL)veterinarians kindName:(NSString *)kindName filterName:(NSString *)filterName count:(NSUInteger)count state:(PPPetCareDiscoveryState)state loading:(BOOL)loading animated:(BOOL)animated
{
    [self configureForSection:veterinarians ? PPPetCareInitialSectionVeterinarians : PPPetCareInitialSectionMedicines
                    kindName:kindName filterName:filterName count:count state:state loading:loading animated:animated];
}

- (void)configureForSection:(PPPetCareInitialSection)section kindName:(NSString *)kindName filterName:(NSString *)filterName count:(NSUInteger)count state:(PPPetCareDiscoveryState)state loading:(BOOL)loading animated:(BOOL)animated
{
    BOOL medicines = section == PPPetCareInitialSectionMedicines;
    BOOL clinics = section == PPPetCareInitialSectionClinics;
    BOOL changedSection = _hasConfiguration && _selectedSection != section;
    _hasConfiguration = YES;
    _selectedSection = section;
    _kindName = [kindName copy];
    _filterName = [filterName copy];
    _count = count;
    _state = state;
    _loading = loading;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    BOOL accessibility = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _modeStack.axis = accessibility ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _scopeStack.axis = accessibility ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _careContainer.hidden = accessibility;
    if (!accessibility) {
        if (_careLottieLoaded) {
            _careLottieView.hidden = NO;
            _careLottieView.alpha = 1.0;
            _careMark.hidden = YES;
            _careMark.alpha = 0.0;
            [self resumeCareAnimationIfNeeded];
        } else {
            _careMark.hidden = NO;
            _careMark.alpha = 1.0;
            _careLottieView.hidden = YES;
            _careLottieView.alpha = 0.0;
        }
    }
    _title.text = kLang(@"pet_care_discovery_title");
    _subtitle.text = kLang(medicines ? @"pet_care_discovery_medicines" : (clinics ? @"pet_care_discovery_clinics" : @"pet_care_discovery_vets"));
    _title.font = PPCareFont(PPFontTitle1, UIFontTextStyleTitle1, YES, self.traitCollection);
    _subtitle.font = PPCareFont(PPFontSubheadline, UIFontTextStyleSubheadline, NO, self.traitCollection);
    _resultLabel.font = PPCareFont(PPFontFootnote, UIFontTextStyleFootnote, YES, self.traitCollection);
    _retainedLabel.font = PPCareFont(PPFontFootnote, UIFontTextStyleFootnote, NO, self.traitCollection);
    _stateTitle.font = PPCareFont(PPFontTitle2, UIFontTextStyleTitle2, YES, self.traitCollection);
    _stateMessage.font = PPCareFont(PPFontBody, UIFontTextStyleBody, NO, self.traitCollection);
    for (UILabel *label in @[_title, _subtitle, _resultLabel, _retainedLabel, _stateTitle, _stateMessage]) {
        label.textAlignment = [Language alignmentForCurrentLanguage];
        label.textColor = (label == _title || label == _stateTitle) ? AppPrimaryTextClr : AppSecondaryTextClr;
    }
    _careMark.tintColor = AppPrimaryClr;
    _stateIcon.tintColor = AppSecondaryTextClr;
    _modeSeparator.backgroundColor = UIColor.separatorColor;
    _selectionLine.backgroundColor = AppPrimaryClr;
    _searchSurface.backgroundColor = AppForgroundColr;
    _stateSurface.backgroundColor = AppForgroundColr;
    _searchIcon.tintColor = AppSecondaryTextClr;
    _searchField.textColor = AppPrimaryTextClr;
    _searchField.tintColor = AppPrimaryClr;
    _searchField.font = PPCareFont(PPFontBody, UIFontTextStyleBody, NO, self.traitCollection);
    _searchField.textAlignment = [Language alignmentForCurrentLanguage];
    _searchField.semanticContentAttribute = self.semanticContentAttribute;
    NSString *placeholder = kLang(medicines ? @"pet_care_search_medicines" : (clinics ? @"pet_care_search_clinics" : @"pet_care_search_vets"));
    _searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: AppSecondaryTextClr}];
    _searchField.accessibilityLabel = placeholder;

    NSArray<UIButton *> *sectionButtons = @[_medicineButton, _vetsButton, _clinicsButton];
    NSArray<NSString *> *sectionTitles = @[@"pet_care_medicines", @"pet_care_veterinarians", @"pet_care_clinics"];
    NSArray<NSString *> *sectionSymbols = @[@"pills", @"stethoscope", @"building.2.crop.circle"];
    for (NSUInteger index = 0; index < sectionButtons.count; index++) {
        UIButton *button = sectionButtons[index];
        BOOL selected = button.tag == section;
        [self styleButton:button title:kLang(sectionTitles[index]) symbol:accessibility && selected ? @"checkmark.circle.fill" : sectionSymbols[index] selected:selected filled:NO];
        // Stacked symbols leave room for three translated titles on compact phones.
        UIButtonConfiguration *configuration = button.configuration;
        configuration.imagePlacement = accessibility ? NSDirectionalRectEdgeLeading : NSDirectionalRectEdgeTop;
        configuration.titleAlignment = accessibility ? UIButtonConfigurationTitleAlignmentLeading : UIButtonConfigurationTitleAlignmentCenter;
        configuration.imagePadding = PPSpaceXS;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceXS, PPSpaceMD, PPSpaceXS);
        button.configuration = configuration;
        button.contentHorizontalAlignment = accessibility ? UIControlContentHorizontalAlignmentLeading : UIControlContentHorizontalAlignmentCenter;
        button.titleLabel.textAlignment = accessibility ? [Language alignmentForCurrentLanguage] : NSTextAlignmentCenter;
        button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        button.selected = selected;
    }
    [self styleButton:_kindButton title:kindName.length ? kindName : kLang(@"pet_care_all_pets") symbol:@"pawprint" selected:NO filled:NO];
    [self styleButton:_filterButton title:filterName.length ? filterName : kLang(@"pet_care_filter_by") symbol:@"slider.horizontal.3" selected:filterName.length > 0 filled:NO];
    _kindButton.accessibilityLabel = kLang(@"pet_care_kind_filter");
    _kindButton.accessibilityValue = kindName.length ? kindName : kLang(@"pet_care_all_pets");
    _filterButton.accessibilityValue = filterName.length ? filterName : kLang(@"pet_care_filter_all");

    [self styleButton:_refreshButton title:@"" symbol:@"arrow.clockwise" selected:NO filled:NO];
    _refreshButton.accessibilityLabel = kLang(@"pet_care_refresh");
    _refreshButton.enabled = !loading;
    _refreshButton.hidden = loading;
    _activity.hidden = !loading;
    if (loading) [_activity startAnimating]; else [_activity stopAnimating];
    if (loading) {
        _resultLabel.text = kLang(count > 0 ? @"pet_care_refreshing" : @"pet_care_loading");
    } else if (count > 0) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar" : @"en"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        _resultLabel.text = [NSString stringWithFormat:kLang(@"pet_care_results_format"), [formatter stringFromNumber:@(count)]];
    } else {
        _resultLabel.text = kLang(medicines ? @"pet_care_medicine_title" : (clinics ? @"pet_care_clinics_title" : @"pet_care_vets_title"));
    }
    _retainedLabel.text = kLang(@"pet_care_retained_error");
    _retainedLabel.hidden = state != PPPetCareDiscoveryStateRetainedError;
    BOOL showsState = state != PPPetCareDiscoveryStateResults && state != PPPetCareDiscoveryStateRetainedError;
    _stateSurface.hidden = !showsState;
    _alternateButton.hidden = !showsState || loading;
    _primaryButton.hidden = loading;
    NSString *symbol = medicines ? @"pills" : (clinics ? @"building.2.crop.circle" : @"stethoscope");
    NSString *titleKey = medicines ? @"pet_care_directory_empty_medicines" : (clinics ? @"pet_care_directory_empty_clinics" : @"pet_care_directory_empty_vets");
    NSString *messageKey = medicines ? @"pet_care_directory_empty_medicines_body" : (clinics ? @"pet_care_directory_empty_clinics_body" : @"pet_care_directory_empty_vets_body");
    NSString *actionKey = @"pet_care_refresh";
    if (state == PPPetCareDiscoveryStateLoading) {
        titleKey = @"pet_care_loading_title";
        messageKey = @"pet_care_loading_body";
    } else if (state == PPPetCareDiscoveryStateError) {
        symbol = @"wifi.exclamationmark";
        titleKey = @"pet_care_load_error";
        messageKey = @"pet_care_load_error_body";
        actionKey = @"pet_care_retry";
    } else if (state == PPPetCareDiscoveryStateNoMatches) {
        symbol = @"magnifyingglass";
        titleKey = @"pet_care_no_matches";
        messageKey = @"pet_care_no_matches_body";
        actionKey = @"pet_care_clear_search_filters";
    }
    _stateIcon.image = [UIImage systemImageNamed:symbol];
    _stateTitle.text = kLang(titleKey);
    _stateMessage.text = kLang(messageKey);
    [self styleButton:_primaryButton title:kLang(actionKey) symbol:state == PPPetCareDiscoveryStateNoMatches ? @"line.3.horizontal.decrease" : @"arrow.clockwise" selected:YES filled:YES];
    NSString *alternateKey = section == PPPetCareInitialSectionVeterinarians ? @"pet_care_explore_medicines" : @"pet_care_explore_vets";
    [self styleButton:_alternateButton title:kLang(alternateKey) symbol:Language.isRTL ? @"arrow.left" : @"arrow.right" selected:NO filled:NO];
    _primaryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    UIButton *selection = medicines ? _medicineButton : (clinics ? _clinicsButton : _vetsButton);
    [_selectionCenter setActive:NO];
    [_selectionWidth setActive:NO];
    _selectionCenter = [_selectionLine.centerXAnchor constraintEqualToAnchor:selection.centerXAnchor];
    _selectionWidth = [_selectionLine.widthAnchor constraintEqualToAnchor:selection.widthAnchor];
    [NSLayoutConstraint activateConstraints:@[_selectionCenter, _selectionWidth]];
    _selectionLine.hidden = accessibility;
    if (changedSection && animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            [self layoutIfNeeded];
        } completion:nil];
    }
    [self setNeedsLayout];
}

- (CGFloat)fittingHeightForWidth:(CGFloat)width
{
    return ceil([self systemLayoutSizeFittingSize:CGSizeMake(MAX(width, 1), 0)
                  withHorizontalFittingPriority:UILayoutPriorityRequired
                        verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (_hasConfiguration) {
        [self configureForSection:_selectedSection kindName:_kindName filterName:_filterName count:_count state:_state loading:_loading animated:NO];
    }
}

#pragma mark - Layout & Lifecycle

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_careLottieLoaded && _careLottieView && !CGRectIsEmpty(_careLottieView.bounds)) {
        if (![_careLottieView isAnimationPlaying] && !_careContainer.hidden && !_careLottieView.hidden) {
            [_careLottieView play];
        }
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self resumeCareAnimationIfNeeded];
    }
}

- (void)resumeCareAnimationIfNeeded
{
    if (_careLottieLoaded && _careLottieView && !_careContainer.hidden && !_careLottieView.hidden) {
        if (![_careLottieView isAnimationPlaying]) {
            [_careLottieView play];
        }
    }
}

#pragma mark - Lottie Animation

- (void)pp_loadCareLottieAnimation
{
    __weak typeof(self) weakSelf = self;
    void (^applyLottieJSON)(NSDictionary *) = ^(NSDictionary *jsonDict) {
        if (![jsonDict isKindOfClass:[NSDictionary class]] || jsonDict.count == 0) {
            NSLog(@"⚠️ PPPetCareDiscoveryView: Invalid JSON dictionary for ecg1.json");
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                NSLog(@"⚠️ PPPetCareDiscoveryView: Failed to build LOTComposition for ecg1.json");
                return;
            }

            self->_careLottieLoaded = YES;
            [self->_careLottieView setSceneModel:composition];
            self->_careLottieView.loopAnimation = YES;
            self->_careLottieView.autoReverseAnimation = NO;
            self->_careLottieView.animationSpeed = 0.5;
            self->_careLottieView.animationProgress = 0.0;
            self->_careLottieView.hidden = NO;

            // Ensure layout bounds are non-zero before triggering Core Animation
            [self layoutIfNeeded];
            [self->_careLottieView layoutIfNeeded];

            [self->_careLottieView play];

            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self->_careLottieView.alpha = 1.0;
                self->_careMark.alpha = 0.0;
            } completion:^(BOOL finished) {
                self->_careMark.hidden = YES;
            }];
        });
    };

    // Tier 1: Check bundled resource first (instant offline/online load)
    NSString *bundledPath = [[NSBundle mainBundle] pathForResource:@"ecg1" ofType:@"json"];
    if (bundledPath.length > 0) {
        NSData *localData = [NSData dataWithContentsOfFile:bundledPath];
        if (localData.length > 0) {
            NSError *jsonErr = nil;
            NSDictionary *localJSON = [NSJSONSerialization JSONObjectWithData:localData options:kNilOptions error:&jsonErr];
            if (localJSON && !jsonErr && [localJSON isKindOfClass:[NSDictionary class]]) {
                NSLog(@"✅ PPPetCareDiscoveryView: Loaded ecg1.json from app bundle");
                applyLottieJSON(localJSON);
                return;
            }
        }
    }

    // Tier 2: Check YYCache (cache key used by AppClasses & Styling)
    YYCache *cache = [[YYCache alloc] initWithName:@"LottieJSONCache"];
    NSString *cacheKey = @"lottie_LottieAnimations/ecg1.json";
    NSDictionary *cachedJSON = (NSDictionary *)[cache objectForKey:cacheKey];
    if (cachedJSON && [cachedJSON isKindOfClass:[NSDictionary class]]) {
        NSLog(@"✅ PPPetCareDiscoveryView: Loaded ecg1.json from cache");
        applyLottieJSON(cachedJSON);
        return;
    }

    // Tier 3: Fetch via Firebase Storage SDK (canonical path "LottieAnimations/ecg1.json")
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/ecg1.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        if (jsonDict && !error) {
            NSLog(@"✅ PPPetCareDiscoveryView: Downloaded ecg1.json via Firebase Storage SDK");
            applyLottieJSON(jsonDict);
            return;
        }

        NSLog(@"⚠️ PPPetCareDiscoveryView: FIRStorage download failed (%@), falling back to direct HTTPS fetch...", error.localizedDescription);

        // Tier 4: Direct HTTPS download fallback (bypasses SDK App Check & Auth constraints)
        NSURL *publicURL = [NSURL URLWithString:@"https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/LottieAnimations%2Fecg1.json?alt=media"];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:publicURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable httpError) {
            if (data && !httpError) {
                NSError *parseError = nil;
                NSDictionary *downloadedJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parseError];
                if (downloadedJSON && !parseError && [downloadedJSON isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"✅ PPPetCareDiscoveryView: Downloaded ecg1.json via direct HTTPS");
                    [cache setObject:downloadedJSON forKey:cacheKey];
                    applyLottieJSON(downloadedJSON);
                    return;
                }
            }

            NSLog(@"❌ PPPetCareDiscoveryView: All sources failed for ecg1.json: %@", httpError.localizedDescription ?: error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self->_careLottieLoaded = NO;
                self->_careMark.hidden = NO;
                self->_careMark.alpha = 1.0;
                self->_careLottieView.hidden = YES;
                self->_careLottieView.alpha = 0.0;
            });
        }];
        [task resume];
    }];
}

- (UIImageView *)careMark
{
    return _careMark;
}

- (LOTAnimationView *)careLottieView
{
    return _careLottieView;
}

- (UIView *)careContainer
{
    return _careContainer;
}

@end
