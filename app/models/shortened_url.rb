# == Schema Information
#
# Table name: shortened_urls
#
#  id         :bigint           not null, primary key
#  long_url   :string           not null
#  short_url  :string           not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ShortenedUrl < ApplicationRecord
    
    validates :short_url, :long_url, uniqueness: true, presence: true 

    belongs_to(
        :submitter,
        class_name: 'User',
        foreign_key: :user_id,
        primary_key: :id
    )

    has_many(
        :visits,
        class_name: 'Visit',
        foreign_key: :shortened_url_id,
        primary_key: :id
    )

    has_many(
        :taggings,
        class_name: 'Taggings',
        foreign_key: :shortened_url_id,
        primary_key: :id
    )

    has_many :visitors,
    Proc.new { distinct }, #<<<
    through: :visits, 
    source: :visitor

    has_many :tag_topics,
    through: :taggings, 
    source: :tag_topic

    def self.random_code
        currentURL = SecureRandom.urlsafe_base64
        while ShortenedUrl.exists?(:short_url => currentURL)
            currentURL = SecureRandom.urlsafe_base64
        end
        return currentURL
    end

    def self.create_for_user_and_long_url!(user, long_url)
        ShortenedUrl.create!(
            long_url: long_url,
            user_id: user.id,
            short_url: ShortenedUrl.random_code
        )
    end

    def num_clicks
        visits.count
    end

    def num_uniques
        visitors.count
        # visits.select('user_id').distinct.count
    end

    def num_recent_uniques
        visits
        .select('visitor_id')
        .where('created_at > ?', 10.minutes.ago)
        .distinct
        .count
    end

    def no_spamming
        last_minute = ShortenedUrl
        .where('created_at >= ?', 1.minute.ago)
        .where(submitter_id: submitter_id)
        .length

        errors[:maximum] << 'of five short urls per minute' if last_minute >= 5
    end

    def nonpremium_max
        return if User.find(self.submitter_id).premium

        number_of_urls =
        ShortenedUrl
            .where(submitter_id: submitter_id)
            .length

        if number_of_urls >= 5
        errors[:Only] << 'premium members can create more than 5 short urls'
        end
    end

    def self.prune(n)
        ShortenedUrl
        .joins(:submitter)
        .joins('LEFT JOIN visits ON visits.shortened_url_id = shortened_urls.id')
        .where("(shortened_urls.id IN (
            SELECT shortened_urls.id
            FROM shortened_urls
            JOIN visits
            ON visits.shortened_url_id = shortened_urls.id
            GROUP BY shortened_urls.id
            HAVING MAX(visits.created_at) < \'#{n.minute.ago}\'
        ) OR (
            visits.id IS NULL and shortened_urls.created_at < \'#{n.minutes.ago}\'
        )) AND users.premium = \'f\'")
        .destroy_all

        # The sql for the query would be:
        #
        # SELECT shortened_urls.*
        # FROM shortened_urls
        # JOIN users ON users.id = shortened_urls.submitter_id
        # LEFT JOIN visits ON visits.shortened_url_id = shortened_urls.id
        # WHERE (shortened_urls.id IN (
        #   SELECT shortened_urls.id
        #   FROM shortened_urls
        #   JOIN visits ON visits.shortened_url_id = shortened_urls.id
        #   GROUP BY shortened_urls.id
        #   HAVING MAX(visits.created_at) < "#{n.minute.ago}"
        # ) OR (
        #   visits.id IS NULL and shortened_urls.created_at < '#{n.minutes.ago}'
        # )) AND users.premium = 'f'
  end
end
