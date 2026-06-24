class Order < ActiveRecord::Base
  belongs_to :textbook
  belongs_to :buyer, class_name: 'User'
  belongs_to :seller, class_name: 'User'
  has_many :reviews

  validates :textbook_id, presence: true
  validates :buyer_id, presence: true
  validates :seller_id, presence: true
  validate :buyer_cannot_be_seller
  validate :textbook_must_be_available, on: :create

  STATUS_FLOW = %w[pending buyer_confirmed seller_confirmed completed].freeze

  def buyer_confirm!
    raise '订单状态不允许此操作' unless status == 'pending'
    update!(status: 'buyer_confirmed', buyer_confirmed_at: Time.current)
    try_complete!
  end

  def seller_confirm!
    raise '订单状态不允许此操作' unless status == 'buyer_confirmed'
    update!(status: 'seller_confirmed', seller_confirmed_at: Time.current)
    try_complete!
  end

  def can_review?(user_id)
    status == 'completed' && !reviews.exists?(reviewer_id: user_id)
  end

  def as_json(options = {})
    super(options.merge(
      include: {
        textbook: { only: [:id, :title, :isbn, :selling_price] },
        buyer: { only: [:id, :name] },
        seller: { only: [:id, :name] },
        reviews: {}
      }
    ))
  end

  private

  def try_complete!
    return unless buyer_confirmed_at && seller_confirmed_at
    textbook = Textbook.find(textbook_id)
    textbook.update!(status: 'sold')
    update!(status: 'completed', completed_at: Time.current)
  end

  def buyer_cannot_be_seller
    errors.add(:buyer_id, '买方不能是卖方本人') if buyer_id == seller_id
  end

  def textbook_must_be_available
    textbook = Textbook.find_by(id: textbook_id)
    errors.add(:textbook_id, '教材已售出或不存在') unless textbook&.status == 'available'
  end
end
