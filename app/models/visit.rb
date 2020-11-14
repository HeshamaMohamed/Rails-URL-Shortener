# == Schema Information
#
# Table name: visits
#
#  id                 :bigint           not null, primary key
#  visitor_id         :integer          not null
#  visited_url_id     :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Visit < ApplicationRecord
  validates :visitor_id, :shortened_url_id, presence: true

  def self.record_visit!(user, shortened_url)
    Visit.create!(
      shortened_url_id: shortened_url.id,
      visitor_id: user.id
    )
  end
  
  belongs_to(
    :visitor,
    class_name: 'User',
    foreign_key: :visitor_id,
    primary_key: :id
  )

  belongs_to(
    :url,
    class_name: 'ShortenedUrl',
    foreign_key: :shortened_url_id,
    primary_key: :id
  )

  
end
