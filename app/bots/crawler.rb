require 'open-uri'

class Crawler
  include ActionView::Helpers::SanitizeHelper

  def process_links(url)
    set_url_links_as_not_found url
    page = get_html url
    sites.each do |site|
      page_links_to_site(page, site).each do |link|
        save_link(url, site, link)
      end
      save_page_metrics(page, url)
    end
  end


  protected

  def save_link(url, site, link)
    link_path = link.attribute('href').to_s

    cmp = campaign link_path, site.campaignId

    db_link = existing_link(link_path, url, site) || new_link
    db_link.site       = site
    db_link.url        = url
    db_link.link       = link_path
    db_link.anchor     = strip_tags link.children.to_s
    db_link.status     = 'link found'
    db_link.campaign   = cmp
    db_link.affiliate  = affiliate? cmp

    db_link.save
  end

  def existing_link(link_path, url, site)
    Link.where(link: link_path, url: url, site: site).first
  end

  def new_link
    Link.new
  end

  ##
  # Get page for a given url
  #
  def get_html(url)
    Nokogiri::HTML(open(url.url))
  end


  ##
  # Get all site related links on a page
  #
  def page_links_to_site(page, site)
    links = []
    page.css('a').each do |link|
      if link.attribute('href').to_s.include? site.domain
        links << link
      end
    end
    links
  end


  ##
  # Get site metrics
  #
  def save_page_metrics(page, url)
    page_domain = url_domain url.url

    metrics = { internal_links: 0, external_links: 0 }
    page.css('a').each do |link|
      if link.attribute('href').to_s.include? page_domain
        metrics[:internal_links] += 1
      else
        metrics[:external_links] += 1
      end
    end

    url.internal_links = metrics[:internal_links]
    url.external_links = metrics[:external_links]
    url.visited_at = Time.now
    url.save
  end


  def url_domain(url)
    url = "http://#{url}" if URI.parse(url).scheme.nil?
    host = URI.parse(url).host.downcase
    host.start_with?('www.') ? host[4..-1] : host
  end

  ##
  # Get all configured sites
  #
  def sites
    Site.all
  end


  ##
  # Get if url is for an affiliate or not
  #
  def affiliate?(campaign)
    return 'yes' if campaign
    'no'
  end


  ##
  # get the campaign parameter for a given url
  #
  def campaign(link, campaing_id)
    query = Rack::Utils.parse_query URI(link).query
    if query.include? campaing_id
      query[campaing_id]
    end
  end


  ##
  # Updates all url related links to status link not found
  #
  def set_url_links_as_not_found(url)
    url.links.update_all(status: 'link not found')
  end

end