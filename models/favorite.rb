class Favorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :textbook

  validates :user_id, uniqueness: { scope: :textbook_id, message: '已收藏该教材' }
end
