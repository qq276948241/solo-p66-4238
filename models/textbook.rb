class Textbook < ActiveRecord::Base
  belongs_to :seller, class_name: 'User'
  has_one :order

  validates :title, presence: true
  validates :isbn, presence: true
  validates :original_price, presence: true, numericality: { greater_than: 0 }
  validates :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :condition_level, inclusion: { in: 0..4 }
  validates :status, inclusion: { in: %w[available sold] }

  CONDITION_MAP = { 0 => '全新', 1 => '九成新', 2 => '八成新', 3 => '一般', 4 => '较差' }.freeze

  def condition_label
    CONDITION_MAP[condition_level]
  end

  def self.filter(course_name: nil, min_price: nil, max_price: nil)
    scope = where(status: 'available')
    scope = scope.where('course_name LIKE ?', "%#{course_name}%") if course_name
    scope = scope.where('selling_price >= ?', min_price.to_f) if min_price
    scope = scope.where('selling_price <= ?', max_price.to_f) if max_price
    scope
  end

  def as_json(options = {})
    super(options.merge(
      methods: [:condition_label],
      include: { seller: { only: [:id, :name, :school_id] } }
    ))
  end
end
