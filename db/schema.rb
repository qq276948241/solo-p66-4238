# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 6) do
  create_table "favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "textbook_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["textbook_id"], name: "index_favorites_on_textbook_id"
    t.index ["user_id", "textbook_id"], name: "index_favorites_on_user_id_and_textbook_id", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.integer "textbook_id", null: false
    t.integer "buyer_id", null: false
    t.integer "seller_id", null: false
    t.string "status", default: "pending"
    t.datetime "buyer_confirmed_at"
    t.datetime "seller_confirmed_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["seller_id"], name: "index_orders_on_seller_id"
    t.index ["textbook_id"], name: "index_orders_on_textbook_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "reviewer_id", null: false
    t.integer "reviewee_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "reviewer_id"], name: "index_reviews_on_order_id_and_reviewer_id", unique: true
    t.index ["order_id"], name: "index_reviews_on_order_id"
  end

  create_table "schools", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_suffix", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_suffix"], name: "index_schools_on_email_suffix", unique: true
  end

  create_table "textbooks", force: :cascade do |t|
    t.string "title", null: false
    t.string "isbn", null: false
    t.decimal "original_price", precision: 10, scale: 2, null: false
    t.decimal "selling_price", precision: 10, scale: 2, null: false
    t.integer "condition_level", default: 0
    t.string "course_name"
    t.text "description"
    t.integer "seller_id", null: false
    t.string "status", default: "available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_name"], name: "index_textbooks_on_course_name"
    t.index ["isbn"], name: "index_textbooks_on_isbn"
    t.index ["seller_id"], name: "index_textbooks_on_seller_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "school_id"
    t.boolean "verified", default: false
    t.string "api_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end
end
