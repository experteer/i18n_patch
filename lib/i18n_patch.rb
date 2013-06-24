require "i18n_patch/version"

require 'action_view'
require 'action_view/base'
require 'digest/md5'

module PjppI18n
  KM_PER_MILE = 1.609344
end

#
# disable builtin rails translation e.g. to avoid problems for number helpers
# better ways?
#
module I18n
  module Backend
    class Simple
      alias :orig_translate :translate
      def translate(locale, key, options = {})
        orig_translate('en', key, options)
      end
    end
  end
end

class I18nInitializer

  def self.initialize_gettext
    GetText.bindtextdomain( 'pjpp', { :path => "#{RAILS_ROOT}/locale", :output_charset => 'utf-8' } )
    # all base classes that use translation need to be bound here.
    #rails classes

    #[ActionController::Base,....].each do |klass|
    #  GetText.textdomain_to(klass, 'pjpp')
    #  klass.send :include,GetText
    #end

    GetText.textdomain_to(ActionController::Base, 'pjpp')
    GetText.textdomain_to(ActiveRecord::Base, 'pjpp')
    GetText.textdomain_to(ActiveRecord::Validations, 'pjpp')
    GetText.textdomain_to(ActionView::Base, 'pjpp')
    GetText.textdomain_to(ActionMailer::Base, 'pjpp')
    #prepare our classes

    GetText.textdomain_to(ActiveModel, 'pjpp')
    GetText.textdomain_to(ActiveForm, 'pjpp')
    GetText.textdomain_to(ApplicationHelper, 'pjpp')
    GetText.textdomain_to(Renderer, 'pjpp')

    ActiveRecord::Base.send :include,GetText
    ActionController::Base.send :include,GetText
    ActionMailer::Base.send :include,GetText
    ActionView::Base.send :include,GetText

  end

end

#
# methods to be included in application controller
#
module PjppI18nTemplatePaths

  protected

=begin rdoc

 choose language dependent template

 (note: language dependent partials are implemented by overwriting ActionView::Partials::partial_pieces)

=end
  def default_template_name(default_action_name = action_name)
    path = "#{$pjpp_locale}/#{$pjpp_template_set}/#{self.class.controller_path}/#{default_action_name}"
    path
  end
=begin rdoc

 choose language/template set/layout set dependent layout

=end
  def get_layout(layout)
    logger.debug( [ 'layout', "#{$pjpp_locale}/#{$pjpp_template_set}/layouts/#{$pjpp_layout_set}/#{layout}" ] )
    "#{$pjpp_locale}/#{$pjpp_template_set}/layouts/#{$pjpp_layout_set}/#{layout}"
  end

=begin rdoc

 choose layout for partner searches

=end
  def get_mktg_layout( affiliate_name )
    logger.debug( [ 'mktg_layout', "../#{$pjpp_country_version}/#{$pjpp_template_set}/partner/#{affiliate_name}/layout" ] )
    raise ActiveRecord::RecordNotFound.new('no such partner') unless Affiliate.by_name( affiliate_name )
    "../#{$pjpp_country_version}/#{$pjpp_template_set}/partner/#{affiliate_name}/layout"
  end

=begin rdoc
build marketing template file name from option hash as provided to render_mktg
=end
  def mktg_template_filename( options )
    if options[:partial]
      partial = options[:partial]
      if partial =~ /\//
        partial = partial.sub(/\/(?!.*\/)/, '/_')
      else
        partial = "_#{partial}"
      end
      if options[:path]
        path = "#{$pjpp_country_version}/#{$pjpp_template_set}/#{options[:path]}"
      else
        path = "#{$pjpp_country_version}/#{$pjpp_template_set}/#{params[:controller]}"
      end
      return "#{path}/#{partial}.rhtml"
    else
      action = options[:action] || params[:action]
      return "#{$pjpp_country_version}/#{$pjpp_template_set}/#{params[:controller]}/#{action}.rhtml"
    end
  end

=begin rdoc
check for the existance of an marketing template
parameters are the same as for render_mktg
=end
  def mktg_template_exists?( options )
    File.exists?( Rails.root.join('app','views',mktg_template_filename( options ) ))
  end
  protected :mktg_template_exists?

=begin rdoc
render marketing template
options:
  :partial  partial name
  :path     path for partial (defaults to controller name)
  :action   action (if no partial name is provided; path is controller name; defaults to params[:action])
  :check_existance  raise  ActiveRecord::RecordNotFound if template does not exist
=end
  def render_mktg( options )
    logger.debug( [ 'render_mktg', options ] )

    options[:file] = mktg_template_filename( options )
    if options[:check_existance]
      notfound unless File.exists?(Rails.root.join('app','views',options[:file]))
    end
    partial=options.delete(:partial)
    options.delete(:path)

    if partial
      render_to_string options.merge(:layout => false)
    else
      render options.reverse_merge(:layout => true)
    end
  end
  protected :render_mktg
end

module PjppI18nLocale
  protected
  def pjpp_set_locale( language )
    Rails.logger.debug( "setting locale to #{language.locale}" )
    $pjpp_language_id = language.id
    $pjpp_locale = language.locale
    GetText.set_locale $pjpp_locale
  end

  def with_localization( country_version, language = :default )
    old_cv    = $pjpp_country_version
    old_cv_id = $pjpp_country_version_id
    old_language_id = $pjpp_language_id

    $pjpp_country_version = country_version.name
    $pjpp_country_version_id = country_version.id
    if language
      if language == :default
        language = Language.find(CountryParameter.get(:default_language_id, country_version.name) )
      end
      pjpp_set_locale( language )
    end
    begin
      yield
    ensure
      $pjpp_country_version    = old_cv
      $pjpp_country_version_id = old_cv_id
      pjpp_set_locale( Language.find( old_language_id ) ) if old_language_id
    end
  end

end

module ActionView
  class Base
    def _pick_partial_template_with_pjpp_hack(partial_path) #:nodoc:
      unless $pjpp_skip_view_path_hack
        if partial_path.include?('/')
          path = "#{$pjpp_locale}/#{$pjpp_template_set}/" + File.join(File.dirname(partial_path), "_#{File.basename(partial_path)}")
        elsif controller
          path = "#{$pjpp_locale}/#{$pjpp_template_set}/#{controller.class.controller_path}/_#{partial_path}"
        else
          path = "#{$pjpp_locale}/#{$pjpp_template_set}/_#{partial_path}"
        end

        self.view_paths.find_template(path, self.template_format)
      else
        _pick_partial_template_without_pjpp_hack(partial_path)
      end
    end
    alias_method_chain :_pick_partial_template, :pjpp_hack
  end
end


class String
=begin rdoc
 provide method to localize a database column
=end
  def localize_column( locale )
    case locale
    when 'DE', 'YY'
      self.clone
    when 'XX'
      "#{self}_en_gb"
    else
      "#{self}_#{locale.downcase}"
    end
  end
end

# not used ATM; in case of re-activation, please take care of proper I18N/L10N
# thomas (2009-12-03)
# class Integer
#   LOW_ORDINALS =
#     { 'DE' => [ 'nullte', 'erste',   'zweite', 'dritte', 'vierte',
#       'fünfte', 'sechste', 'siebte', 'achte',  'neunte' ],
#     'EN_GB' => [ 'nullth',  'first', 'second',  'third',  'fourth',
#       'fifth',   'sixth', 'seventh', 'eighth', 'nineth' ],
#     'EN_GB' => [ 'zeroeth', 'first', 'second',  'third',  'fourth',
#       'fifth',   'sixth', 'seventh', 'eighth', 'nineth' ],
#     'FR' => [ 'zeroième', { :male => 'premier', :female => 'première' },
#       'deuxième', 'troisième', 'quatrième', 'cinquième',
#       'sixième', 'septième', 'huitième', 'neuvième' ],
#     'IT' => [ 'nullo',  'primo', 'secondo',  'terzo',  'quarto',
#       'quinto', 'sesto', 'settimo',  'ottavo', 'nono' ] }
#   HIGH_ORDINAL_POSTFIX = { 'DE' => 'te', 'EN_US' => 'th', 'EN_GB' => 'th',
#     'FR' => 'ième', 'IT' => 'esimo' }
# =begin rdoc
#   Outputs the integer as an ordinal. Integers between 0 and 10 are mapped to
#   words, taking gender into account if neccessary. Integer above 10 are given
#   a postfix string to indicate ordinality.

#   If called on integers less than 0, an exception is raised.

#   gender can be either a universal setting of :male, :female or :other, or a
#   hash that sets the gender for each language, e.g.
#
#   x.to_ordinal( { 'FR' => :female, 'IT' => :male }, language )
#
#   Unspecified genders are mapped to :other. This can lead to a return value of
#   'nil' for languages where no gender :other exists, for instance french.
# =end
#   def to_ordinal(gender = :other, locale=$pjpp_locale)
#     raise "Ordinality for numbers < 0 not defined" if self < 0
#     if self < 10
#       use_gender = ( gender.kind_of?( Hash ) ?  gender[locale] : gender ) || :other

#       LOW_ORDINALS[locale][self].kind_of?( Hash ) ?
#         LOW_ORDINALS[locale][self][use_gender] :
#         LOW_ORDINALS[locale][self]
#     else
#       "#{self}#{HIGH_ORDINAL_POSTFIX[locale]}"
#     end
#   end
# end

class Object
=begin rdoc
  Calls to gettext() return a frozen string. To make the string malable again,
  we need to explicitly create a copy. thaw is just an alias of dup, thus
  returning a copy of the original object, it doesn't unfreeze the original
  object (Rubys frozen objects can't be unfrozen).
=end
  alias_method :thaw, :dup


  # 10.06.2009 - mow FIXME: shouldn't these methods use begin/ensure to reset the locale?
  # e.g.
  # $pjpp_locale = 'DE'; begin; with_locale( 'EN' ) { raise 'foo' }; rescue; end; $pjpp_locale
  # will leave $pjpp_locale at 'EN'.
  # Besides: setting $pjpp_locale alone does *not* change a language setting.
  # and we do have $pjpp_language_id and $pjpp_locale that should match...
  def with_locale( locale )
    # DEPRECATED
    old_locale = $pjpp_locale
    $pjpp_locale = locale
    yield
    $pjpp_locale = old_locale
  end

  def with_country_version( cv_spec )
    # DEPRECATED
    old_cv    = $pjpp_country_version
    old_cv_id = $pjpp_country_version_id

    if cv_spec.kind_of? CountryVersion
      $pjpp_country_version_id = cv_spec.id
      $pjpp_country_version    = cv_spec.name
    elsif cv_spec.respond_to? :country_version
      $pjpp_country_version_id = cv_spec.country_version.id
      $pjpp_country_version    = cv_spec.country_version.name
    elsif cv_spec.kind_of? Numeric || ( cv_spec.respond_to? :to_i && cv_spec.to_i > 0 )
      $pjpp_country_version_id = cv_spec.to_i
      $pjpp_country_version    = CountryVersion.by_id cv_spec.to_i
    elsif cv_spec.kind_of? String
      $pjpp_country_version    = cv_spec
      $pjpp_country_version_id = CountryVersion.by_name cv_spec
    else
      raise "Unknown CV Spec '#{cv_spec}' of type #{cv_spec.class}"
    end

    yield

    $pjpp_country_version    = old_cv
    $pjpp_country_version_id = old_cv_id
  end

end
