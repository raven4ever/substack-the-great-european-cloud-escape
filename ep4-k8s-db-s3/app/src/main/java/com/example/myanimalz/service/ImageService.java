package com.example.myanimalz.service;

import java.io.ByteArrayInputStream;
import java.time.Instant;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import io.awspring.cloud.s3.ObjectMetadata;
import io.awspring.cloud.s3.S3Template;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class ImageService {

    private final S3Template s3Template;
    private final RestClient restClient;
    private final String bucketName;
    private final String randomImageUrl;

    public ImageService(
            S3Template s3Template,
            @Value("${app.bucket-name}") String bucketName,
            @Value("${app.random-image-url}") String randomImageUrl) {
        this.s3Template = s3Template;
        this.restClient = RestClient.create();
        this.bucketName = bucketName;
        this.randomImageUrl = randomImageUrl;
    }

    public String downloadAndStoreRandomImage() {
        byte[] imageBytes = restClient.get()
                .uri(randomImageUrl)
                .retrieve()
                .body(byte[].class);

        if (imageBytes == null || imageBytes.length == 0) {
            throw new IllegalStateException("Empty response body from " + randomImageUrl);
        }

        String key = String.format("random-image-%d.jpg", Instant.now().toEpochMilli());

        ObjectMetadata metadata = ObjectMetadata.builder()
                .contentType("image/jpeg")
                .contentLength((long) imageBytes.length)
                .build();

        s3Template.upload(bucketName, key, new ByteArrayInputStream(imageBytes), metadata);
        log.info("Uploaded random image to s3://{}/{} ({} bytes)", bucketName, key, imageBytes.length);

        return key;
    }
}
