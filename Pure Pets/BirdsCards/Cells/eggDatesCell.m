//
//  eggDatesCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/12/2024.
//

#import "eggDatesCell.h"
#import "PrefixHeader.pch"
#import "Language.h"

@implementation eggDatesCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    if (self.cellLabel) return;

    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    self.cellLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.cellLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.cellLabel.font = [GM MidFontWithSize:13];
    [self.contentView addSubview:self.cellLabel];

    self.selectedDateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.selectedDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedDateLabel.font = [GM MidFontWithSize:15];
    self.selectedDateLabel.textColor = UIColor.secondaryLabelColor;
    [self.contentView addSubview:self.selectedDateLabel];

    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [GM MidFontWithSize:12];
    self.dateLabel.textColor = UIColor.secondaryLabelColor;
    self.dateLabel.text = [Language languageVal] == 0 ? @"Edit" : @"تعديل";
    self.dateLabel.userInteractionEnabled = YES;
    [self.contentView addSubview:self.dateLabel];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showPickBtnTapped)];
    singleTap.numberOfTapsRequired = 1;
    [self.dateLabel addGestureRecognizer:singleTap];

    [NSLayoutConstraint activateConstraints:@[
        [self.cellLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.cellLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],

        [self.dateLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.dateLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.selectedDateLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.selectedDateLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.cellLabel.trailingAnchor constant:8],
        [self.selectedDateLabel.trailingAnchor constraintEqualToAnchor:self.dateLabel.leadingAnchor constant:-12]
    ]];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    self.selectedDateLabel.text = nil;
    self.dateLabel.textColor = UIColor.secondaryLabelColor;
}

-(void)showPickBtnTapped
{
    [self.delegate showDatePicKer:_currentInexPath];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

@end
