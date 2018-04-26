#!/usr/bin/perl
use JSON;

my $CONFIG;
{
local $/ = undef;
open(F,"./cf-associations.json") || die $!;
$CONFIG = decode_json(<F>);
close(F);
}

foreach my $distribution (@{$CONFIG}) {
  unlink("./$distribution->{'distributionId'}.json");
  my $CFConfig = decode_json(`aws cloudfront get-distribution-config --id $distribution->{'distributionId'}`);
  if ($distribution->{'DefaultCacheBehavior'}) {
    foreach my $cb (@{$distribution->{'DefaultCacheBehavior'}->{'Items'}}) {
      $cb->{'LambdaFunctionARN'} =~ /^.+:(.+):$/;
      my $newArn = `aws lambda publish-version --function-name $1 --region us-east-1 | jq -r '.FunctionArn'`;
      chomp($newArn);
      $cb->{'LambdaFunctionARN'} = $newArn;
    }
    $CFConfig->{'DistributionConfig'}->{'DefaultCacheBehavior'}->{'LambdaFunctionAssociations'} = $distribution->{'DefaultCacheBehavior'};
  } 
  foreach my $cache (@{$distribution->{'CacheBehaviors'}}) {
    foreach my $cb (@{$cache->{'rules'}->{'Items'}}) {
      $cb->{'LambdaFunctionARN'} =~ /^.+:(.+):$/;
      my $newArn = `aws lambda publish-version --function-name $1 --region us-east-1 | jq -r '.FunctionArn'`;
      chomp($newArn);
      $cb->{'LambdaFunctionARN'} = $newArn;
    }
    foreach my $item (@{$CFConfig->{'DistributionConfig'}->{'CacheBehaviors'}->{'Items'}}) {
      if ($item->{'PathPattern'} eq $cache->{'path'}) {
        $item->{'LambdaFunctionAssociations'} = $cache->{'rules'};
        last;
      }
    } 
  
  }
  open(F,">./$distribution->{'distributionId'}.json");
  print F encode_json($CFConfig->{'DistributionConfig'});
  close(F);
  print `aws cloudfront update-distribution --id $distribution->{'distributionId'} --region us-east-1 --distribution-config=file://$distribution->{'distributionId'}.json --if-match $CFConfig->{'ETag'}`;
  unlink("./$distribution->{'distributionId'}.json");
}


__DATA__
The format of the JSON configuration for this script is:

[
  {
    "distributionId":"ASDFASDFASDF",
    "DefaultCacheBehavior": 
      {
        "Quantity": 2,
        "Items": [
          {
            "LambdaFunctionARN": "arn:aws:lambda:us-east-1:123456:function:somefunction:",
            "EventType": "origin-response"
          },
          {
            "LambdaFunctionARN": "arn:aws:lambda:us-east-1:123456:function:baisc-auth:",
            "EventType": "viewer-request"
          }
        ]
      },
    "CacheBehaviors": [
      {
        "path": "/csp*",
        "rules": 
        {
          "Quantity": 2,
          "Items": [
            {
              "LambdaFunctionARN": "arn:aws:lambda:us-east-1:123456:function:somefunction:",
              "EventType": "origin-response"
            },
            {
              "LambdaFunctionARN": "arn:aws:lambda:us-east-1:123456:function:baisc-auth:",
              "EventType": "viewer-request"
            }
          ]
        }
      },
      {
        "path": "/blog*",
        "rules": 
        {
          "Quantity": 0
        }
      }
    ]
  }
]