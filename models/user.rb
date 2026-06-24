require 'securerandom'

class User < ActiveRecord::Base
  belongs_to :school, optional: true
  has_many :textbooks, foreign_key: :seller_id
  has_many :buy_orders, class_name: 'Order', foreign_key: :buyer_id
  has_many :sell_orders, class_name: 'Order', foreign_key: :seller_id
  has_many :given_reviews, class_name: 'Review', foreign_key: :reviewer_id
  has_many :received_reviews, class_name: 'Review', foreign_key: :reviewee_id

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password_digest, presence: true

  before_validation :auto_verify_school, on: :create
  before_create :generate_api_token

  has_secure_password

  CONDITION_LEVELS = { 0 => '全新', 1 => '九成新', 2 => '八成新', 3 => '一般', 4 => '较差' }.freeze

  def self.condition_levels
    CONDITION_LEVELS
  end

  def self.authenticate(email, password)
    user = find_by(email: email)
    user&.authenticate(password)
  end

  def self.find_by_token(token)
    find_by(api_token: token)
  end

  private

  def auto_verify_school
    return if email.blank?
    domain = email.split('@').last
    school = School.find_by(email_suffix: domain)
    if school
      self.school_id = school.id
      self.verified = true
    else
      self.verified = false
    end
  end

  def generate_api_token
    self.api_token = SecureRandom.hex(16)
  end
end
