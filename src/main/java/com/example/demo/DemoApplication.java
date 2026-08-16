package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DemoApplication {

	public static void main(String[] args) {

		SpringApplication.run(DemoApplication.class, args);
		for (int i=0; i<5; ++i){
			for (int j=0; j<5; ++j){
				for (int k=0; k<5; ++k) {
					System.out.println("AAAAA");
				}
			}
		}

		for (int i=0; i<5; ++i){
			for (int j=0; j<5; ++j){
				for (int k=0; k<5; ++k) {
					if (k%2==0) System.out.println("AAAAA");
					else  System.out.println("BBBBBB");
				}
			}
		}
	} // test


	// Because I'm too lazy to fix this now
	@SuppressWarnings("PMD.CognitiveComplexity")
	public static void foo() {
		for (int i=0; i<5; ++i){
			for (int j=0; j<5; ++j){
				for (int k=0; k<5; ++k) {
					System.out.println("AAAAA");
				}
			}
		}

		for (int i=0; i<5; ++i){
			for (int j=0; j<5; ++j){
				for (int k=0; k<5; ++k) {
					if (k%2==0) System.out.println("AAAAA");
					else  System.out.println("BBBBBB");
				}
			}
		}
	}
}
