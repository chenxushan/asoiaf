//
//  SubCategoryTable.m
//  A Song of Ice and Fire
//
//  Created by Vicent Tsai on 15/12/4.
//  Copyright © 2015年 HeZhi Corp. All rights reserved.
//

#import "SubCategoryTable.h"
#import "CategoryViewController.h"

@interface SubCategoryTable () <CMBaseTableDelegate>

@end

@implementation SubCategoryTable

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [super setDelegate:self];
    }
    return self;
}

- (void)setParentCategory:(CategoryMemberModel *)parentCategory
{
    [super setParentCategory:parentCategory];

    [[CategoryManager sharedManager]
     getCategoryMember:parentCategory.link memberType:CMCategoryType parameters:nil completionBlock:^(CategoryMembersModel *members) {
        self.members = members.members;

        if (members.cmcontinue) {
            [self.nextContinue addObject:members.cmcontinue];
        }

        if (self.members.count > 0) {
            [self.tableView reloadData];
        }
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CategoryMemberModel *member = self.members[indexPath.row];

    CategoryViewController *subCategoryVC = [[CategoryViewController alloc] init];
    subCategoryVC.category = member;
    subCategoryVC.portalType = self.parentVC.portalType;

    [self.parentVC.navigationController pushViewController:subCategoryVC animated:YES];
}

#pragma mark - CMBaseTableDelegate

- (void)getMembersWithCategory:(NSString *)categoryLink
                    parameters:(NSDictionary *)parameters
               completionBlock:(void (^)(CategoryMembersModel * _Nonnull))completionBlock
{
    [[CategoryManager sharedManager] getCategoryMember:categoryLink
                                            memberType:CMCategoryType
                                            parameters:parameters
                                       completionBlock:completionBlock];
}

@end
