package Plugins::GoogleMusic::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use Slim::Player::Playlist;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

use Plugins::GoogleMusic::Plugin;
use Plugins::GoogleMusic::GoogleAPI;
use Plugins::GoogleMusic::Image;

my $log = logger('plugin.googlemusic');
my $prefs = preferences('plugin.googlemusic');

Slim::Player::ProtocolHandlers->registerHandler('googlemusic', __PACKAGE__);

# Always MP3
sub getFormatForURL { 'mp3' }

# Avoid scanning
sub scanUrl {
	my ($class, $url, $args) = @_;

	$args->{cb}->( $args->{song}->currentTrack() );
}

sub getNextTrack {
	my ($class, $song, $successCb, $errorCb) = @_;
	  
	my $url    = $song->currentTrack()->url;
	  
	my ($id) = $url =~ m{^googlemusic:track:(.*)$};

	# TBD: Error handling. Call errorCb or errors.
	my $trackURL = $googleapi->get_stream_url($id, $prefs->get('device_id'));

	$song->streamUrl($trackURL);
	# To support seeking set duration and bitrate
	$song->duration($song->currentTrack()->secs);
	# Always 320k at Google Music
	$song->bitrate(320000);

	$successCb->();
}

sub canDirectStreamSong {
	my ( $class, $client, $song ) = @_;
	
	# We need to check with the base class (HTTP) to see if we
	# are synced or if the user has set mp3StreamingMethod
	return $class->SUPER::canDirectStream( $client, $song->streamUrl(), $class->getFormatForURL($song->track->url()) );
}

sub getMetadataFor {
	my ($class, $client, $url) = @_; 

	my $track = $googleapi->get_track($url);
	my $secs = $track->{'durationMillis'} / 1000;
	my $image = Plugins::GoogleMusic::Image->uri($track->{'albumArtUrl'});

	return {
		title    => $track->{'title'},
		artist   => $track->{'artist'},
		album    => $track->{'album'},
		duration => $secs,
		cover    => $image,
		icon     => $image,
		bitrate  => '320k CBR',
		type     => 'MP3 (Google Music)',
		albumuri => $track->{'myAlbum'}->{'uri'},
		artistA  => $track->{'myAlbum'}->{'artist'},
	};
}

sub trackInfoURL {
	my ( $class, $client, $url ) = @_;

	my $track = $googleapi->get_track($url);
	my $secs = $track->{'durationMillis'} / 1000;

	# divert to other handler
	#if ($otherHandler && $prefs->get('othermeta')) {
	#	return $class->SUPER::trackInfoURL($client, $url);
	#}

	my $items = [
		{
			type =>  'text',
			name =>  $track->{'artist'},
			label => 'ARTIST',
		},
		{ type  => 'text',
		  label => 'TITLE',
		  name  => $track->{'title'},
		},
		{
			type    => 'playlist',
			url     => $track->{'myAlbum'}->{'uri'},
			name    => $track->{'album'},
			label   => 'ALBUM',
		},
		{
			type    => 'playlist',
			name    => $track->{'year'},
			label   => 'YEAR',
		},
		{
			type  => 'text',
			label => 'LENGTH',
			name  => sprintf('%d:%02d', int($secs / 60), $secs % 60),
		},
		];

	my $image = Plugins::GoogleMusic::Image->uri($track->{'albumArtUrl'});

	return {
		name  => $track->{'title'},
		type  => 'opml',
		items => $items,
		play  => $track->{'url'},
		cover => $image,
		menuComplete => 1,
	};
}
