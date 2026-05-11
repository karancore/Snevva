import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/models/diet_tags_response.dart';

void main() {
  group('DietTagsResponse.fromJson', () {
    test('normalizes media maps and nullable meal fields from diet API', () {
      final response = DietTagsResponse.fromJson({
        'status': true,
        'statusType': 'success',
        'message': 'Ok',
        'data': [
          {
            'Id': '66',
            'DataCode': 'diet-code',
            'ThumbnailMedia': {
              'CdnUrl': 'd3byuuhm0bg21i.cloudfront.net/originals/thumb.jpg',
            },
            'Heading': 'Vegetarian Diet',
            'Title': 'Home-style Indian meals',
            'ShortDescription': 'Calorie-dense meals',
            'MealPlan': [
              {
                'Day': '1',
                'BreakFast': null,
                'BreakFastMedia': {
                  'CdnUrl':
                      'd3byuuhm0bg21i.cloudfront.net/originals/breakfast.jpg',
                },
                'Lunch': 'Dal-rice',
                'LunchMedia': 'https://example.com/lunch.jpg',
                'Evening': null,
                'EveningMedia': null,
                'Dinner': 'Paneer, rice',
                'DinnerMedia': {'url': '//example.com/dinner.jpg'},
              },
            ],
            'Tags': ['Vegetarian', 42],
            'IsActive': true,
          },
        ],
      });

      final diet = response.data!.single;
      final meal = diet.mealPlan.single;

      expect(diet.id, 66);
      expect(
        diet.thumbnailMedia,
        'https://d3byuuhm0bg21i.cloudfront.net/originals/thumb.jpg',
      );
      expect(diet.tags, ['Vegetarian', '42']);
      expect(meal.day, 1);
      expect(meal.breakFast, '');
      expect(
        meal.breakFastMedia,
        'https://d3byuuhm0bg21i.cloudfront.net/originals/breakfast.jpg',
      );
      expect(meal.lunchMedia, 'https://example.com/lunch.jpg');
      expect(meal.evening, '');
      expect(meal.dinnerMedia, 'https://example.com/dinner.jpg');
    });
  });
}
