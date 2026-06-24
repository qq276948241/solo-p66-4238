class Review < ActiveRecord::Base
  belongs_to :order
  belongs_to :reviewer, class_name: 'User'
  belongs_to :reviewee, class_name: 'User'

  validates :rating, presence: true, inclusion: { in: 1..5, message: '评分必须在1-5之间' }
  validates :reviewer_id, uniqueness: { scope: :order_id, message: '每个订单只能评价一次' }
  validate :order_must_be_completed
  validate :reviewer_must_be_participant

  def as_json(options = {})
    super(options.merge(
      include: {
        reviewer: { only: [:id, :name] },
        reviewee: { only: [:id, :name] }
      }
    ))
  end

  private

  def order_must_be_completed
    errors.add(:order_id, '订单未完成，不能评价') unless order&.status == 'completed'
  end

  def reviewer_must_be_participant
    return unless order
    unless [order.buyer_id, order.seller_id].include?(reviewer_id)
      errors.add(:reviewer_id, '评价者必须是订单参与方')
    end
  end
end
