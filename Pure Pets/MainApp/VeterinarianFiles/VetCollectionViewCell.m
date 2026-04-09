//
//  VetCollectionViewCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//


#import "VetCollectionViewCell.h"
#import "VetModel.h"
#import "AppManager.h"

@interface VetCollectionViewCell ()
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, assign) BOOL isOwnedByUser;
@end

@implementation VetCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat imageSize = frame.size.width;
        
        _logoImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, imageSize, imageSize)];
        _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
        _logoImageView.clipsToBounds = YES;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, CGRectGetMaxY(_logoImageView.frame) -40 , frame.size.width - 32, 20)];
        _titleLabel.font = [GM boldFontWithSize:16];
        _titleLabel.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        _titleLabel.numberOfLines = 1;
        _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;

        _typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, CGRectGetMaxY(_titleLabel.frame) + 2, frame.size.width - 32, 18)];
        _typeLabel.font = [GM MidFontWithSize:12];
        _typeLabel.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        _typeLabel.numberOfLines = 1;
        _typeLabel.textColor = UIColor.secondaryLabelColor;
        
        [self.contentView addSubview:_logoImageView];
        
        UIView *upView = [[UIView alloc] initWithFrame:CGRectMake(0, self.contentView.hx_h - 45, self.contentView.hx_w, 45)];
        upView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.7];
        [self.contentView addSubview:upView];
        
      
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_typeLabel];

        self.contentView.backgroundColor = AppForgroundColr;
        self.contentView.layer.cornerRadius = 25;
        self.contentView.clipsToBounds = YES;

        CGFloat btnSize = 28;
        CGFloat padding = 6;

        _shareButton = [[UIButton alloc] initWithFrame:CGRectMake(padding, self.contentView.hx_h - btnSize - padding, btnSize, btnSize)];
        [_shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        [_shareButton setTintColor:UIColor.whiteColor];
        [_shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];

        _deleteButton = [[UIButton alloc] initWithFrame:CGRectMake(frame.size.width - btnSize - padding, self.contentView.hx_h - btnSize - padding, btnSize, btnSize)];
        [_deleteButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
        [_deleteButton setTintColor:UIColor.whiteColor];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];

        _editButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMinX(_deleteButton.frame) - btnSize - padding, self.contentView.hx_h - btnSize - padding, btnSize, btnSize)];
        [_editButton setImage:[UIImage systemImageNamed:@"square.and.pencil"] forState:UIControlStateNormal];
        [_editButton setTintColor:UIColor.whiteColor];
        [_editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];

        [self.contentView addSubview:_shareButton];
        [self.contentView addSubview:_editButton];
        [self.contentView addSubview:_deleteButton];
        
        
        CGFloat buttonSize = 28;
        
        if(Language.languageVal == 0)
        {
            self.shareButton.frame = CGRectMake(self.contentView.hx_w -  padding - buttonSize, padding - 3, buttonSize, buttonSize);
            self.favButton.frame = CGRectMake(self.shareButton.hx_x -  padding - buttonSize , padding, buttonSize, buttonSize);
            self.deleteButton.frame = CGRectMake(self.favButton.hx_x -  padding - buttonSize, padding, buttonSize, buttonSize);
        }
        else
        {
            self.shareButton.frame = CGRectMake(padding, padding - 3, buttonSize, buttonSize);
            self.favButton.frame = CGRectMake(CGRectGetMaxX(self.shareButton.frame) + padding, padding, buttonSize, buttonSize);
            self.deleteButton.frame = CGRectMake(CGRectGetMaxX(self.favButton.frame) + padding, padding, buttonSize, buttonSize);
        }

        [self setupShadow];
    }
    return self;
}

- (void)configureWithVet:(VetModel *)vet isUserOwned:(BOOL)isOwned {
    self.isOwnedByUser = isOwned;

    self.titleLabel.text = vet.title;
    self.typeLabel.text = vet.type == VetTypeCompany ? @"شركة" : @"شخصي";
    [GM setImageFromUrlString:vet.logoURL imageView:self.logoImageView phImage:@"placeholder"];
    
    self.shareButton.hidden = isOwned;
    self.deleteButton.hidden = !isOwned;
    self.editButton.hidden = !isOwned;
}

- (void)shareTapped {
    
    if(!UserManager.sharedManager.currentAuthUser)
    {
        [UserManager showPromptOnTopController];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapShare:)]) {
        [self.delegate vetCellDidTapShare:self];
    }
}

- (void)deleteTapped {
    
    if(!UserManager.sharedManager.currentAuthUser)
    {
        [UserManager showPromptOnTopController];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapDelete:)]) {
        [self.delegate vetCellDidTapDelete:self];
    }
}

- (void)editTapped {
    
    if(!UserManager.sharedManager.currentAuthUser)
    {
        [UserManager showPromptOnTopController];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapEdit:)]) {
        [self.delegate vetCellDidTapEdit:self];
    }
}



- (void)setupShadow {
    self.contentView.layer.cornerRadius = 15.0;
    self.contentView.layer.masksToBounds = YES;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 4.0;
    self.layer.shadowOpacity = 0.25;
    self.layer.masksToBounds = NO;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:8.0].CGPath;
}

@end
